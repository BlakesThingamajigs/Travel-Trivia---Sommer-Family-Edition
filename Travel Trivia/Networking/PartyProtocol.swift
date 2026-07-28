//
//  PartyProtocol.swift
//  Travel Trivia
//
//  Everything that crosses the wire between phones. The model is strictly
//  host-authoritative: clients send small intents, the host applies them to
//  the one true PartyState and rebroadcasts the whole thing. Full-state
//  sync (a few KB even with a dealt question deck) is deliberate — it
//  makes reconnection and host migration trivial because any device can
//  rebuild the entire party from the last snapshot it saw.
//

import Foundation

/// Multipeer service type (Bonjour: `_travel-trivia._tcp`). Max 15 chars.
nonisolated enum PartyWire {
    static let serviceType = "travel-trivia"
    static let maxPlayers = 6  // one per car seat
    static let disconnectGrace: Duration = .seconds(45)
}

nonisolated enum DifficultyTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case familyMix = "family-mix"
    case littleOnes = "little-ones"
    case grownUp = "grown-up-challenge"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .familyMix: "Family Mix"
        case .littleOnes: "Little Ones"
        case .grownUp: "Grown-Up Challenge"
        }
    }

    var blurb: String {
        switch self {
        case .familyMix: "A little of everything for the whole car"
        case .littleOnes: "Easy ones for the smallest riders"
        case .grownUp: "Tough stuff for the big kids up front"
        }
    }

    /// Which question difficulties this tier deals from.
    var allowedDifficulties: Set<Difficulty> {
        switch self {
        case .familyMix: [.easy, .medium, .hard]
        case .littleOnes: [.easy]
        case .grownUp: [.medium, .hard]
        }
    }
}

nonisolated enum PartyRole: String, Codable, Sendable {
    case none, pilot, copilot

    var badge: String? {
        switch self {
        case .none: nil
        case .pilot: "PILOT"
        case .copilot: "COPILOT"
        }
    }
}

nonisolated enum PlayerPresence: String, Codable, Sendable {
    case connected
    /// Lost their connection; inside the grace window. Seat dims, score
    /// freezes, game keeps moving without them.
    case dropped
    /// Grace expired. Still listed so final results include them.
    case left
}

nonisolated struct PartyConfig: Codable, Equatable, Sendable {
    var modeSlug: String
    var modeName: String
    var genreSlug: String
    var genreName: String
    var difficulty: DifficultyTier
    var minPlayers: Int
    /// Mirrors GameMode.requiresEvenPlayers — Team Relay needs two equal
    /// squads, so the Lobby gates a short/odd start the same way it gates
    /// an under-minimum start.
    var requiresEvenPlayers: Bool = false
}

nonisolated struct PartyPlayerState: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var colorIndex: Int
    var seatIndex: Int?
    var role: PartyRole = .none
    var presence: PlayerPresence = .connected
    var score: Int = 0
    var strikes: Int = 0
    var lastAnswerCorrect: Bool?
    /// Team Relay: which squad (0 or 1) this rider is on; nil = unassigned.
    var teamIndex: Int?
    /// Double or Nothing: the amount wagered on the bonus question currently
    /// open, cleared once that question settles.
    var pendingWager: Int?
}

nonisolated enum PartyPhase: String, Codable, Sendable {
    case lobby, ride, playing, victory
}

/// Copilot's Curveball rules, shared by host logic and every screen.
nonisolated enum CopilotsCurveball {
    static let modeSlug = "copilots-curveball"
    /// Every Nth question is a Curveball Question.
    static let cadence = 4
    /// How long the copilot's early peek lasts before the question opens
    /// to the whole car.
    static let previewDuration: Duration = .seconds(6)

    static func isCurveballIndex(_ questionIndex: Int) -> Bool {
        (questionIndex + 1) % cadence == 0
    }
}

/// Elimination Bracket rules: sudden death instead of the three-strikes
/// model everyone else uses. The threshold lives here, keyed off the mode,
/// so `GameEngine.maxStrikes` (Three Strikes, Copilot's Curveball) stays a
/// plain constant — both `PartySession` and the rendering layer (`Player`)
/// read the same mode-aware number.
nonisolated enum Elimination {
    static let bracketModeSlug = "elimination-bracket"

    /// How many wrong answers a player can take before they're out.
    /// Elimination Bracket: one. Team Relay: effectively unlimited — an
    /// individual relay-turn player's strikes shouldn't end the game while
    /// their teammates haven't had a turn yet; the round only ends when the
    /// deck runs out. Everything else: the classic three.
    static func maxStrikes(modeSlug: String) -> Int {
        switch modeSlug {
        case bracketModeSlug: 1
        case TeamRelay.modeSlug: .max
        default: GameEngine.maxStrikes
        }
    }
}

/// Team Relay rules, shared by host logic and every screen.
nonisolated enum TeamRelay {
    static let modeSlug = "team-relay"
}

/// Round-length floor: sudden death (one player left standing) shouldn't be
/// able to end a round after just a couple of quick strike-outs, now that
/// dealt decks routinely run 26-70+ questions. A solo survivor keeps
/// answering against the deck (everyone else already eliminated sits out)
/// until this many questions have been asked, or the deck runs out —
/// whichever comes first. Applies to every mode, not just Elimination
/// Bracket, since every mode shares the same `advance()` sudden-death check.
nonisolated enum RoundLength {
    static let minQuestionsBeforeSuddenDeath = 15
}

/// Herd Reveal rules: any genre's normally-authored questions, scored by
/// whichever answer won the car's vote instead of the authored answer.
nonisolated enum HerdReveal {
    static let modeSlug = "herd-reveal"
}

/// Double or Nothing rules, shared by host logic and every screen.
nonisolated enum DoubleOrNothing {
    static let modeSlug = "double-or-nothing"
    /// Every Nth question is a wager question.
    static let cadence = 4
    /// How long players get to lock in a wager before the bonus question
    /// opens for answers.
    static let wagerWindow: Duration = .seconds(8)

    static func isWagerIndex(_ questionIndex: Int) -> Bool {
        (questionIndex + 1) % cadence == 0
    }
}

nonisolated struct RoundState: Codable, Equatable, Sendable {
    /// The dealt deck, shuffled by the host; identical on every device.
    var questions: [TriviaQuestion]
    var questionIndex: Int = 0
    var revealing: Bool = false
    /// What counts as correct for the question being revealed: the authored
    /// answer, or the majority pick for prediction questions. Nil outside
    /// the reveal (and when literally nobody voted).
    var resolvedCorrectOptionID: String?
    /// Copilot's Curveball: the current question is inside its early-reveal
    /// window — only the copilot's device shows it, and no answers are
    /// accepted yet.
    var curveballPreview: Bool = false
    /// Genre actually in play this game (differs from config when the
    /// Shuffle Genres setting rerolled it).
    var genreSlug: String
    var genreName: String
    var winnerID: UUID?
    /// Team Relay: whose turn it is to answer for each squad — index 0/1,
    /// rotating to the next connected teammate every question.
    var teamTurnPlayerID: [UUID?] = [nil, nil]
    /// Double or Nothing: the current (wager) question is inside its
    /// lock-in window — wagers are being collected and no answers are
    /// accepted yet.
    var wagerOpen: Bool = false
}

nonisolated struct PartyState: Codable, Equatable, Sendable {
    var partyName: String
    var code: String
    /// Bumped on host migration so joiners always pick the newest host if a
    /// zombie advertisement is still floating around.
    var epoch: Int = 0
    var hostID: UUID
    /// Designated at party creation (first joiner); promoted if the host
    /// device drops.
    var backupHostID: UUID?
    var config: PartyConfig
    var phase: PartyPhase = .lobby
    var players: [PartyPlayerState] = []
    var round: RoundState?
    /// Host-only "Pause & Reshuffle Seats": the in-flight round, frozen here
    /// while `phase` drops back to `.ride` for reseating. Non-nil exactly
    /// when the car is mid-pause rather than starting a fresh game — lets
    /// every screen tell the two `.ride` phases apart. Resuming restores
    /// `round` from this and clears it.
    var pausedRound: RoundState?

    func player(_ id: UUID) -> PartyPlayerState? {
        players.first { $0.id == id }
    }

    var connectedCount: Int {
        players.filter { $0.presence == .connected }.count
    }

    var meetsPlayerRequirement: Bool {
        let count = connectedCount
        guard count >= config.minPlayers else { return false }
        if config.requiresEvenPlayers, count % 2 != 0 { return false }
        if config.modeSlug == TeamRelay.modeSlug, !everyConnectedPlayerHasATeam { return false }
        return true
    }

    /// Team Relay only: every connected rider needs a squad, and both
    /// squads need at least one member, or their relay turn slot sits
    /// permanently empty -- the round would otherwise silently play
    /// through every question with nobody able to answer (see
    /// `holdIfNobodyCanAnswer`, which exists for a fully-disconnected car,
    /// not an unassigned one).
    var everyConnectedPlayerHasATeam: Bool {
        let connected = players.filter { $0.presence == .connected }
        guard connected.allSatisfy({ $0.teamIndex != nil }) else { return false }
        return Set(connected.compactMap(\.teamIndex)).count >= 2
    }
}

/// Client → host. Small, single-purpose requests.
nonisolated enum ClientIntent: Codable, Sendable {
    /// First message after connecting (also how a reconnecting player — or a
    /// mesh-surviving client after host migration — introduces itself so the
    /// host can map its peer to the stable playerID).
    case hello(playerID: UUID, name: String)
    case requestSeat(playerID: UUID, seatIndex: Int)
    case submitAnswer(playerID: UUID, optionID: String)
    /// Double or Nothing: lock in a wager for the bonus question currently
    /// open. Clamped host-side to [0, current score].
    case submitWager(playerID: UUID, amount: Int)
    /// Deliberate exit — host skips the grace window entirely.
    case goodbye(playerID: UUID)
}

nonisolated enum WireMessage: Codable, Sendable {
    /// Host → everyone: the authoritative snapshot.
    case state(PartyState)
    case intent(ClientIntent)
    /// Host → everyone: the host closed the party on purpose (no migration).
    case partyEnded
    /// Host → everyone: the host is leaving a game already in progress on
    /// purpose (not ending the party) — the designated backup should
    /// promote itself right away instead of waiting to notice the host
    /// went quiet, and everyone else should treat the host as gone
    /// immediately rather than waiting out MCSession's slow disconnect
    /// notice.
    case hostLeaving
    /// Presence heartbeats. MCSession can take 30+ seconds to notice an
    /// abruptly-dead peer (dead battery, tunnel), which would stall the
    /// round waiting on a ghost — these keep dropout detection snappy.
    case ping
    case pong(playerID: UUID)

    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    static func decoded(from data: Data) throws -> WireMessage {
        try JSONDecoder().decode(WireMessage.self, from: data)
    }
}

/// The invitation context a joiner sends with its connection attempt: the
/// host validates the code before letting the peer into the session.
nonisolated struct JoinRequest: Codable, Sendable {
    var code: String
    var playerID: UUID
    var name: String
}
