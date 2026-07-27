//
//  LocalProfile.swift
//  Travel Trivia
//
//  The local player's identity and app settings. Everything here lives in
//  UserDefaults on this device only — non-host players never have accounts
//  (deliberate COPPA sidestep), so name + stable player id persisting
//  locally is what makes their identity survive trip to trip. The stable
//  id is also what lets a dropped phone reclaim its seat and score when it
//  reconnects mid-game.
//

import Foundation
import Observation

@Observable
final class LocalProfile {
    private let defaults: UserDefaults

    /// Stable across launches; the party layer keys reconnection off this.
    let playerID: UUID

    var displayName: String {
        didSet { defaults.set(displayName, forKey: Keys.displayName) }
    }

    /// Randomize the genre each game instead of using the Create Game pick.
    var shuffleGenres: Bool {
        didSet { defaults.set(shuffleGenres, forKey: Keys.shuffleGenres) }
    }

    /// Persisted now, routed to real audio in a future session.
    var audioOutput: AudioOutput {
        didSet { defaults.set(audioOutput.rawValue, forKey: Keys.audioOutput) }
    }

    enum AudioOutput: String, CaseIterable, Identifiable {
        case bluetooth, phoneSpeaker

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .bluetooth: "Car Bluetooth"
            case .phoneSpeaker: "Phone Speaker"
            }
        }
    }

    var hasCustomDisplayName: Bool {
        defaults.string(forKey: Keys.displayName) != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: Keys.playerID), let id = UUID(uuidString: stored) {
            playerID = id
        } else {
            playerID = UUID()
            defaults.set(playerID.uuidString, forKey: Keys.playerID)
        }
        displayName = defaults.string(forKey: Keys.displayName) ?? "Player"
        shuffleGenres = defaults.bool(forKey: Keys.shuffleGenres)
        audioOutput = defaults.string(forKey: Keys.audioOutput)
            .flatMap(AudioOutput.init(rawValue:)) ?? .bluetooth
    }

    private enum Keys {
        static let playerID = "tt.local.playerID"
        static let displayName = "tt.local.displayName"
        static let shuffleGenres = "tt.settings.shuffleGenres"
        static let audioOutput = "tt.settings.audioOutput"
    }
}
