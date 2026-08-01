//
//  NarratorVoice.swift
//  Travel Trivia
//
//  4 named narrator personas, each resolved at runtime to whichever
//  Enhanced/Premium-quality system voice on this device best matches its
//  character — never a hardcoded voice identifier, since Enhanced/Premium
//  voices are an optional download (Settings → Accessibility → Spoken
//  Content → Voices) and which ones exist on a given phone varies. A
//  persona with no on-device match is "needs downloading", not silently
//  swapped for the robotic default — see SettingsView's narrator section.
//

import AVFoundation
import Foundation
import SwiftData

enum NarratorPersona: String, CaseIterable, Identifiable, Codable {
    case coPilot, tourGuide, adventurer, hypeMan

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coPilot: "The Co-Pilot"
        case .tourGuide: "The Tour Guide"
        case .adventurer: "The Adventurer"
        case .hypeMan: "The Hype Man"
        }
    }

    var tagline: String {
        switch self {
        case .coPilot: "Upbeat, friendly, energetic"
        case .tourGuide: "Posh, refined, British-accented"
        case .adventurer: "Warm, calm, storyteller"
        case .hypeMan: "High-energy game-show announcer"
        }
    }

    /// The language every match is scored against first. Only the Tour
    /// Guide is language-locked (a persona defined entirely by its British
    /// accent isn't the Tour Guide without one) — the others prefer
    /// American English but will settle for any Enhanced/Premium English
    /// voice rather than reporting "needs downloading" over an accent
    /// mismatch alone.
    fileprivate var primaryLanguage: String {
        switch self {
        case .tourGuide: "en-GB"
        default: "en-US"
        }
    }
    fileprivate var requiresPrimaryLanguage: Bool { self == .tourGuide }

    fileprivate var preferredGender: AVSpeechSynthesisVoiceGender {
        switch self {
        case .coPilot: .female
        case .tourGuide: .male
        case .adventurer: .male
        case .hypeMan: .male
        }
    }

    /// Resolution runs in this order (not `allCases`' display order) so the
    /// most language-constrained persona (Tour Guide) claims its match
    /// before the other three — who'd otherwise happily take an en-GB
    /// voice too — compete over the rest.
    fileprivate static let resolutionOrder: [NarratorPersona] = [.tourGuide, .coPilot, .adventurer, .hypeMan]
}

/// The subset of `AVSpeechSynthesisVoice` the matching logic needs,
/// abstracted so tests can score against synthetic voices instead of
/// depending on which Enhanced/Premium voices happen to be downloaded on
/// the machine running the test.
protocol SpeechVoiceDescribing {
    var identifier: String { get }
    var name: String { get }
    var language: String { get }
    var gender: AVSpeechSynthesisVoiceGender { get }
    var quality: AVSpeechSynthesisVoiceQuality { get }
}
extension AVSpeechSynthesisVoice: SpeechVoiceDescribing {}

enum NarratorVoiceCatalog {
    enum Availability {
        case available(name: String)
        case needsDownload
    }

    /// Every Enhanced/Premium English voice installed on this device.
    /// Excludes `.default` quality (the "Compact" voices that ship on
    /// every device and read as robotic) — those are what narration
    /// already falls back to when a persona isn't selected or resolvable.
    static func candidateVoices() -> [any SpeechVoiceDescribing] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en") && $0.quality != .default
        }
    }

    /// Assigns each persona the best-scoring, not-yet-claimed candidate
    /// voice. A persona with no candidate left (none installed, or every
    /// English Enhanced/Premium voice already claimed by an earlier
    /// persona in `resolutionOrder`) is simply absent from the result —
    /// callers treat a missing entry as "needs downloading".
    static func resolve(from voices: [any SpeechVoiceDescribing] = candidateVoices())
        -> [NarratorPersona: any SpeechVoiceDescribing] {
        var claimed = Set<String>()
        var result: [NarratorPersona: any SpeechVoiceDescribing] = [:]
        let eligible = voices.filter { $0.quality != .default && $0.language.hasPrefix("en") }
        for persona in NarratorPersona.resolutionOrder {
            let ranked = eligible
                .filter { !claimed.contains($0.identifier) }
                .compactMap { voice -> (any SpeechVoiceDescribing, Int)? in
                    guard let score = score(voice, for: persona) else { return nil }
                    return (voice, score)
                }
                .sorted { $0.1 > $1.1 }
            if let best = ranked.first {
                result[persona] = best.0
                claimed.insert(best.0.identifier)
            }
        }
        return result
    }

    /// Nil disqualifies the voice outright (wrong language for a
    /// language-locked persona); higher is a better match otherwise.
    private static func score(_ voice: any SpeechVoiceDescribing, for persona: NarratorPersona) -> Int? {
        var score = 0
        if voice.language == persona.primaryLanguage {
            score += 100
        } else if persona.requiresPrimaryLanguage {
            return nil
        } else {
            score += 10
        }
        if voice.gender == persona.preferredGender { score += 20 }
        if voice.quality == .premium { score += 5 }
        return score
    }

    static func availability(for persona: NarratorPersona,
                              resolved: [NarratorPersona: any SpeechVoiceDescribing] = resolve()) -> Availability {
        if let voice = resolved[persona] { .available(name: voice.name) }
        else { .needsDownload }
    }
}

/// This player's narrator voice pick — local-only, one row per `playerID`,
/// same pattern as `AvatarLoadout`. Stores the persona, not a specific
/// voice identifier: which physical voice a persona resolves to can change
/// launch to launch (a voice gets downloaded, or removed to free space),
/// and re-resolving fresh each time is what makes availability detection
/// correct instead of stale.
@Model
final class NarratorVoicePreference {
    var playerID: UUID
    /// Nil = system default voice (no persona picked) — narration's
    /// original, pre-persona behavior.
    var personaRawValue: String?

    var persona: NarratorPersona? {
        get { personaRawValue.flatMap(NarratorPersona.init(rawValue:)) }
        set { personaRawValue = newValue?.rawValue }
    }

    init(playerID: UUID) {
        self.playerID = playerID
        self.personaRawValue = nil
    }
}
