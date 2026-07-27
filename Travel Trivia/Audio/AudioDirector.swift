//
//  AudioDirector.swift
//  Travel Trivia
//
//  The app's first audio-playback pipeline: plays the bundled sound clips
//  behind the 3 audio genres (Animal Sounds Safari, Sound FX Guess, Name
//  That Tune) and respects the existing Settings Bluetooth/phone-speaker
//  toggle, which nothing routed through before this. Narration (reading
//  question prompts aloud) is a separate follow-up that will build on this
//  same session/routing setup rather than duplicating it.
//
//  Output routing: Settings' Bluetooth/phone-speaker choice is read fresh
//  before every playback — "phone speaker" forcibly overrides the output
//  port so it wins even with a car already connected; "Bluetooth" clears
//  any override and lets the system route to whatever's connected (falling
//  back to the phone speaker itself when nothing is).
//

import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class AudioDirector {
    private(set) var isPlayingClip = false

    private let profile: LocalProfile
    private var clipPlayer: AVAudioPlayer?
    private let clipDelegate = ClipDelegate()

    private var pendingClipCompletion: (@MainActor () -> Void)?

    init(profile: LocalProfile) {
        self.profile = profile
        clipDelegate.onFinish = { [weak self] in
            Task { @MainActor in
                self?.isPlayingClip = false
                self?.pendingClipCompletion?()
                self?.pendingClipCompletion = nil
            }
        }
    }

    // MARK: - Session setup / routing

    /// Call once at launch (and it's safe to call again if the route needs
    /// re-asserting).
    func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default,
                                     options: [.allowBluetoothA2DP, .duckOthers])
            try session.setActive(true)
            applyOutputRoute()
        } catch {
            // No audio session on this device/config — clip playback will
            // silently no-op rather than crash the game.
        }
    }

    /// Re-reads the Settings preference and re-asserts the output route.
    /// Called before every playback so a mid-game Settings change always
    /// takes effect on the next clip.
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

    // MARK: - Clip playback

    func playClip(url: URL, completion: (@MainActor () -> Void)? = nil) {
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

    /// The audio-genre flow: play the genre's sound clip. Text-only genres
    /// have no clip, so this is a no-op for them.
    func presentQuestion(_ question: TriviaQuestion, genreSlug: String) {
        guard let url = AudioClipLibrary.url(for: question, genreSlug: genreSlug) else { return }
        playClip(url: url)
    }

    func stopAll() {
        stopClip()
    }
}

private final class ClipDelegate: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
