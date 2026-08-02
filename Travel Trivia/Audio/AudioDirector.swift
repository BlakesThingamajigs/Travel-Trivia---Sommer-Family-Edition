//
//  AudioDirector.swift
//  Travel Trivia
//
//  The app's one audio pipeline: clip playback for the 3 audio genres
//  (Part D) and question narration (Part E) both go through the same
//  AVAudioPlayer here — narration is synthesized on-device (see
//  NarratorSpeechSynthesizer) into a scratch WAV file and played back
//  exactly like a bundled genre clip, rather than through a second,
//  parallel audio path. They share session setup, the Settings output-
//  routing toggle, and nav-prompt interruption handling too.
//
//  Output routing: Settings' Bluetooth/phone-speaker choice is read fresh
//  before every playback — "phone speaker" forcibly overrides the output
//  port so it wins even with a car already connected; "Bluetooth" clears
//  any override and lets the system route to whatever's connected (falling
//  back to the phone speaker itself when nothing is).
//
//  Nav-prompt pausing: per the party/multiplayer architecture doc, turn-by-
//  turn directions from Maps/Waze should pause the game rather than duck
//  under it. Built here using AVAudioSession's interruption notification,
//  the standard signal apps get when another app (Maps included) takes the
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
    /// True while narration is being synthesized or sounding.
    private(set) var isSpeaking = false
    private(set) var isPlayingClip = false

    private let profile: LocalProfile
    private var player: AVAudioPlayer?
    private let playerDelegate = ClipDelegate()

    /// Work paused mid-interruption, resumed once the interruption ends.
    private enum PausedWork {
        case none
        case narration(String, completion: (@MainActor () -> Void)?)
        case clip(URL, completion: (@MainActor () -> Void)?)
    }
    private var pausedWork: PausedWork = .none

    init(profile: LocalProfile, progress: ProgressStore) {
        self.profile = profile
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

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

    /// Speaks `text` aloud (host/narrator's phone) — a no-op that still
    /// fires `completion` immediately if narration is off in Settings, so
    /// callers that chain work off narration finishing (e.g. presentQuestion
    /// playing a genre clip after the prompt is read) keep working whether
    /// or not narration itself ran.
    func speak(_ text: String, completion: (@MainActor () -> Void)? = nil) {
        guard profile.narratorEnabled else {
            completion?()
            return
        }
        guard !isInterrupted else {
            pausedWork = .narration(text, completion: completion)
            return
        }
        stopClip()
        applyOutputRoute()
        isSpeaking = true
        Task { [weak self] in
            guard let self else { return }
            let url = await NarratorSpeechSynthesizer.shared.synthesize(text)
            await MainActor.run {
                guard let url else {
                    self.isSpeaking = false
                    completion?()
                    return
                }
                self.playAudioFile(url: url, isNarration: true, completion: completion)
            }
        }
    }

    // MARK: - Clip playback (Part D)

    func playClip(url: URL, completion: (@MainActor () -> Void)? = nil) {
        guard !isInterrupted else {
            pausedWork = .clip(url, completion: completion)
            return
        }
        applyOutputRoute()
        playAudioFile(url: url, isNarration: false, completion: completion)
    }

    func stopClip() {
        player?.stop()
        player = nil
        isPlayingClip = false
    }

    /// The shared playback path for both narration audio and genre clips —
    /// one AVAudioPlayer, one delegate, dispatching to whichever of
    /// isSpeaking/isPlayingClip actually applies.
    private func playAudioFile(url: URL, isNarration: Bool, completion: (@MainActor () -> Void)?) {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = playerDelegate
            player = audioPlayer
            if isNarration { isSpeaking = true } else { isPlayingClip = true }
            playerDelegate.onFinish = { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    if isNarration { self.isSpeaking = false } else { self.isPlayingClip = false }
                    completion?()
                }
            }
            audioPlayer.play()
        } catch {
            if isNarration { isSpeaking = false } else { isPlayingClip = false }
            completion?()
        }
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
                self.player?.pause()
            case .ended:
                self.isInterrupted = false
                self.applyOutputRoute()
                if let player = self.player, !player.isPlaying {
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

private final class ClipDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
