//
//  AudioDirector.swift
//  Travel Trivia
//
//  The app's one audio pipeline: clip playback for the 3 audio genres
//  (Part D) and question narration (Part E) both go through here, so they
//  share session setup, the Settings output-routing toggle, and nav-prompt
//  interruption handling instead of each building their own.
//
//  Output routing: Settings' Bluetooth/phone-speaker choice is read fresh
//  before every playback — "phone speaker" forcibly overrides the output
//  port so it wins even with a car already connected; "Bluetooth" clears
//  any override and lets the system route to whatever's connected (falling
//  back to the phone speaker itself when nothing is).
//
//  Nav-prompt pausing: per the party/multiplayer architecture doc, turn-by-
//  turn directions from Maps/Waze should pause the game rather than duck
//  under it. Nothing in the repo implemented that before this session — a
//  grep for "pause" across Travel Trivia/ turned up nothing. This is built
//  here for real using AVAudioSession's interruption notification, the
//  standard signal apps get when another app (Maps included) takes the
//  audio session. It's the correct, testable mechanism for this, but it
//  hasn't been verified against a real live Maps/Waze turn-by-turn prompt
//  (that's not practically triggerable in the simulator) — only against a
//  synthetic interruption in the same way the OS delivers one.
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class AudioDirector {
    /// True while a system interruption (nav prompt, phone call, another
    /// app's audio) is holding playback — QuestionView / GameEngine can key
    /// off this to visually indicate "the game paused for the car."
    private(set) var isInterrupted = false
    /// True while a clip or narration line is actively sounding.
    private(set) var isSpeaking = false
    private(set) var isPlayingClip = false

    private let profile: LocalProfile
    private let progress: ProgressStore
    private let synthesizer = AVSpeechSynthesizer()
    private let speechDelegate = SpeechDelegate()
    private var clipPlayer: AVAudioPlayer?
    private let clipDelegate = ClipDelegate()

    /// Work paused mid-interruption, resumed once the interruption ends.
    private enum PausedWork {
        case none
        case narration(String, completion: (@MainActor () -> Void)?)
        case clip(URL, completion: (@MainActor () -> Void)?)
    }
    private var pausedWork: PausedWork = .none

    init(profile: LocalProfile, progress: ProgressStore) {
        self.profile = profile
        self.progress = progress
        synthesizer.delegate = speechDelegate
        speechDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
                self?.pendingSpeechCompletion?()
                self?.pendingSpeechCompletion = nil
            }
        }
        clipDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                self?.isPlayingClip = false
                self?.pendingClipCompletion?()
                self?.pendingClipCompletion = nil
            }
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    private var pendingSpeechCompletion: (@MainActor () -> Void)?
    private var pendingClipCompletion: (@MainActor () -> Void)?

    // MARK: - Session setup / routing

    /// Call once at launch (and it's safe to call again if the route needs
    /// re-asserting, e.g. after returning from an interruption).
    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default,
                                     options: [.allowBluetoothA2DP, .duckOthers])
            try session.setActive(true)
            applyOutputRoute()
        } catch {
            // No audio session on this device/config — clips/narration will
            // silently no-op rather than crash the game.
        }
    }

    /// Re-reads the Settings preference and re-asserts the output route.
    /// Called before every playback so a mid-game Settings change (or a
    /// route re-assert after an interruption) always takes effect.
    private func applyOutputRoute() {
        let session = AVAudioSession.sharedInstance()
        do {
            switch profile.audioOutput {
            case .phoneSpeaker:
                try session.overrideOutputAudioPort(.speaker)
            case .bluetooth:
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            // Route override isn't available (e.g. no output to override) —
            // playback still proceeds on the default route.
        }
    }

    // MARK: - Narration (Part E)

    /// Speaks `text` aloud (host/narrator's phone). No-op if narration is
    /// already in flight — callers should check `isSpeaking` before
    /// stacking narration for a new question.
    func speak(_ text: String, completion: (@MainActor () -> Void)? = nil) {
        guard !isInterrupted else {
            pausedWork = .narration(text, completion: completion)
            return
        }
        stopClip()
        applyOutputRoute()
        pendingSpeechCompletion = completion
        isSpeaking = true
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.0
        utterance.voice = resolvedPersonaVoice()
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }

    /// Nil falls back to `speak()`'s default system voice — either no
    /// persona is picked, or the picked persona's voice isn't (or is no
    /// longer) downloaded on this device. Re-resolved every call rather
    /// than cached, since voice availability can change between launches.
    private func resolvedPersonaVoice() -> AVSpeechSynthesisVoice? {
        guard let persona = progress.narratorVoicePreference.persona,
              let identifier = NarratorVoiceCatalog.resolve()[persona]?.identifier else { return nil }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }

    // MARK: - Clip playback (Part D)

    func playClip(url: URL, completion: (@MainActor () -> Void)? = nil) {
        guard !isInterrupted else {
            pausedWork = .clip(url, completion: completion)
            return
        }
        applyOutputRoute()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = clipDelegate
            clipPlayer = player
            pendingClipCompletion = completion
            isPlayingClip = true
            player.play()
        } catch {
            isPlayingClip = false
            completion?()
        }
    }

    func stopClip() {
        clipPlayer?.stop()
        clipPlayer = nil
        isPlayingClip = false
    }

    /// The audio-genre flow: narrate the prompt, then — once narration
    /// finishes so the two never overlap — play the genre's sound clip.
    /// Text-only genres just narrate.
    func presentQuestion(_ question: TriviaQuestion, genreSlug: String) {
        speak(question.prompt) { [weak self] in
            guard let self, let url = AudioClipLibrary.url(for: question, genreSlug: genreSlug) else { return }
            self.playClip(url: url)
        }
    }

    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        stopClip()
        isSpeaking = false
        pausedWork = .none
    }

    // MARK: - Nav-prompt interruption handling

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.isInterrupted = true
                if self.isSpeaking {
                    self.synthesizer.pauseSpeaking(at: .word)
                }
                self.clipPlayer?.pause()
            case .ended:
                self.isInterrupted = false
                self.applyOutputRoute()
                if self.synthesizer.isPaused {
                    self.synthesizer.continueSpeaking()
                } else if let player = self.clipPlayer, !player.isPlaying {
                    player.play()
                }
                switch self.pausedWork {
                case .none: break
                case let .narration(text, completion):
                    self.pausedWork = .none
                    self.speak(text, completion: completion)
                case let .clip(url, completion):
                    self.pausedWork = .none
                    self.playClip(url: url, completion: completion)
                }
            @unknown default:
                break
            }
        }
    }
}

/// AVSpeechSynthesizerDelegate needs an NSObject; kept tiny and separate so
/// AudioDirector itself doesn't have to be one.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinish?()
    }
}

private final class ClipDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
