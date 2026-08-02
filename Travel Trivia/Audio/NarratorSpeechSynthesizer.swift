//
//  NarratorSpeechSynthesizer.swift
//  Travel Trivia
//
//  Fully on-device neural TTS: sherpa-onnx (Apache-2.0, k2-fsa) running a
//  bundled Piper VITS voice model, en_US-amy-medium (MIT — see
//  Resources/NarratorVoice/en_US-amy-medium/MODEL_CARD). No network calls
//  at any point, consistent with the app's offline-first design — the
//  model, tokens, and espeak-ng phonemizer data all ship in the app
//  bundle. This only turns text into a WAV file on disk; it does no audio
//  *playback* itself. AudioDirector.speak() plays the result back through
//  the same AVAudioPlayer pipeline already used for genre sound clips,
//  rather than standing up a second audio path.
//
//  The espeak-ng-data folder must survive bundling as a real directory
//  (its phonemizer looks up files like lang/gmw/en-US by relative path) —
//  it's added to the Xcode project as an explicit folder reference, not
//  left to the file-system-synchronized group's default handling, which
//  flattens nested resource folders (see AudioClipLibrary.swift).
//

import Foundation

/// Confines the sherpa-onnx C++ engine (an `OpaquePointer` under the hood,
/// not Sendable) to one serial queue instead of crossing actor boundaries
/// with it directly — same shape as this file's AVFoundation delegate
/// wrappers use for non-Sendable framework types.
final class NarratorSpeechSynthesizer: @unchecked Sendable {
    static let shared = NarratorSpeechSynthesizer()

    private let queue = DispatchQueue(label: "tt.narrator-tts", qos: .userInitiated)
    private lazy var engine: SherpaOnnxOfflineTtsWrapper? = Self.makeEngine()

    private init() {}

    /// Synthesizes `text` off the main thread and writes it to a scratch
    /// WAV file, returning its URL — or nil if the engine couldn't load or
    /// generation failed for any reason. Never throws: a synthesis miss
    /// should mean "skip narration this time," not a crash.
    func synthesize(_ text: String) async -> URL? {
        guard !text.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard let engine, let audio = generate(engine, text) else {
                    continuation.resume(returning: nil)
                    return
                }
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("narration-\(UUID().uuidString).wav")
                guard audio.save(filename: url.path) != 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }

    private func generate(_ engine: SherpaOnnxOfflineTtsWrapper, _ text: String) -> SherpaOnnxGeneratedAudioWrapper? {
        let audio = engine.generate(text: text)
        return audio.n > 0 ? audio : nil
    }

    private static func makeEngine() -> SherpaOnnxOfflineTtsWrapper? {
        guard let modelDir = Bundle.main.url(forResource: "en_US-amy-medium", withExtension: nil) else {
            return nil
        }
        let model = modelDir.appendingPathComponent("en_US-amy-medium.onnx").path
        let tokens = modelDir.appendingPathComponent("tokens.txt").path
        let dataDir = modelDir.appendingPathComponent("espeak-ng-data").path
        let fm = FileManager.default
        guard fm.fileExists(atPath: model), fm.fileExists(atPath: tokens),
              fm.fileExists(atPath: dataDir) else { return nil }

        let vits = sherpaOnnxOfflineTtsVitsModelConfig(model: model, tokens: tokens, dataDir: dataDir)
        let modelConfig = sherpaOnnxOfflineTtsModelConfig(vits: vits, numThreads: 2, provider: "cpu")
        var config = sherpaOnnxOfflineTtsConfig(model: modelConfig)
        return SherpaOnnxOfflineTtsWrapper(config: &config)
    }
}
