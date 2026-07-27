//
//  ContentCatalog.swift
//  Travel Trivia
//
//  The mode/genre catalog shown in Create Game. Fetched live from the
//  Supabase `modes`/`genres` tables when the client is configured and
//  reachable; otherwise the bundled fallback (a mirror of the seed
//  migration) keeps the app fully working in a cell dead zone — the same
//  offline-resilience rule the rest of the game follows.
//

import Foundation
import Observation
import Supabase

nonisolated struct GameMode: Identifiable, Equatable, Codable, Sendable {
    let slug: String
    let displayName: String
    let minPlayers: Int
    let requiresEvenPlayers: Bool
    let isTeamBased: Bool

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName = "display_name"
        case minPlayers = "min_players"
        case requiresEvenPlayers = "requires_even_players"
        case isTeamBased = "is_team_based"
    }

    /// Only Three Strikes has real gameplay behind it this session.
    var isPlayable: Bool { slug == "three-strikes" }
}

nonisolated struct TriviaGenre: Identifiable, Equatable, Codable, Sendable {
    let slug: String
    let displayName: String
    let contentType: String
    let needsMedia: Bool

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case displayName = "display_name"
        case contentType = "content_type"
        case needsMedia = "needs_media"
    }

    /// Only Riddle Realm has seeded questions so far.
    var hasContent: Bool { slug == "riddle-realm" }
}

@Observable
final class ContentCatalog {
    enum Source: Equatable {
        case bundled
        case live
    }

    private(set) var modes: [GameMode] = ContentCatalog.bundledModes
    private(set) var genres: [TriviaGenre] = ContentCatalog.bundledGenres
    private(set) var source: Source = .bundled
    private(set) var isRefreshing = false

    /// Genres eligible when the Shuffle Genres setting randomizes per game.
    var contentReadyGenres: [TriviaGenre] { genres.filter(\.hasContent) }

    func mode(slug: String) -> GameMode? { modes.first { $0.slug == slug } }
    func genre(slug: String) -> TriviaGenre? { genres.first { $0.slug == slug } }

    /// Pulls the live tables; keeps whatever we already have on any failure.
    func refresh() async {
        guard let client = SupabaseService.client, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let liveModes: [GameMode] = try await client
                .from("modes").select().order("display_name").execute().value
            let liveGenres: [TriviaGenre] = try await client
                .from("genres").select().order("display_name").execute().value
            guard !liveModes.isEmpty, !liveGenres.isEmpty else { return }
            modes = liveModes
            genres = liveGenres
            source = .live
        } catch {
            // Offline or misconfigured — the bundled catalog stands.
        }
    }

    // MARK: - Bundled fallback (mirrors supabase/migrations seed)

    nonisolated static let bundledModes: [GameMode] = [
        GameMode(slug: "elimination-bracket", displayName: "Elimination Bracket",
                 minPlayers: 4, requiresEvenPlayers: true, isTeamBased: false),
        GameMode(slug: "team-relay", displayName: "Team Relay",
                 minPlayers: 4, requiresEvenPlayers: true, isTeamBased: true),
        GameMode(slug: "copilots-curveball", displayName: "Copilot's Curveball",
                 minPlayers: 2, requiresEvenPlayers: false, isTeamBased: false),
        GameMode(slug: "herd-reveal", displayName: "Herd Reveal",
                 minPlayers: 3, requiresEvenPlayers: false, isTeamBased: false),
        GameMode(slug: "double-or-nothing", displayName: "Double or Nothing",
                 minPlayers: 2, requiresEvenPlayers: false, isTeamBased: false),
        GameMode(slug: "three-strikes", displayName: "Three Strikes",
                 minPlayers: 2, requiresEvenPlayers: false, isTeamBased: false),
    ]

    nonisolated static let bundledGenres: [TriviaGenre] = [
        TriviaGenre(slug: "animal-sounds-safari", displayName: "Animal Sounds Safari",
                    contentType: "sound", needsMedia: true),
        TriviaGenre(slug: "sound-fx-guess", displayName: "Sound FX Guess",
                    contentType: "sound", needsMedia: true),
        TriviaGenre(slug: "name-that-tune", displayName: "Name That Tune",
                    contentType: "sound", needsMedia: true),
        TriviaGenre(slug: "globe-trotter-clues", displayName: "Globe-Trotter Clues",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "movie-quote-mashup", displayName: "Movie Quote Mashup",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "would-you-rather", displayName: "Would You Rather",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "riddle-realm", displayName: "Riddle Realm",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "mythical-creatures-legends", displayName: "Mythical Creatures & Legends",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "random-acts-of-weird-facts", displayName: "Random Acts of Weird Facts",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "superlative-showdown", displayName: "Superlative Showdown",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "time-machine", displayName: "Time Machine",
                    contentType: "read", needsMedia: false),
        TriviaGenre(slug: "pop-culture-time-capsule", displayName: "Pop Culture Time Capsule",
                    contentType: "read", needsMedia: false),
    ]
}
