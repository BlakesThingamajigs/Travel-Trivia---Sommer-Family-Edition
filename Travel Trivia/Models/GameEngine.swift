//
//  GameEngine.swift
//  Travel Trivia
//
//  The screens' single source of round truth, in one of two contexts:
//
//  - practice: the session-1 single-device slice — every alive player
//    answers each question "simultaneously", the user by tapping, simulated
//    players by an accuracy roll. Kept for tests, previews, and debug runs.
//  - party: a real Multipeer game. The engine becomes a mirror of the
//    host's synced PartyState — local taps route through PartySession
//    (intents on clients, authority on the host) and every broadcast
//    snapshot is applied back here for the screens to render.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class GameEngine {
    nonisolated static let maxStrikes = 3

    enum Phase: Equatable {
        case ride, playing, victory
    }

    enum TurnState: Equatable {
        case awaitingAnswer, revealing
    }

    enum PlayContext: Equatable {
        case practice, partyHost, partyClient
    }

    private(set) var phase: Phase = .ride
    private(set) var players: [Player] = []
    private(set) var questions: [TriviaQuestion] = []
    private(set) var questionIndex = 0
    private(set) var turnState: TurnState = .awaitingAnswer
    private(set) var userPickedOptionID: String?
    /// The option treated as correct for the question being revealed: the
    /// authored answer, or the party's majority pick for prediction
    /// questions. Nil outside the reveal.
    private(set) var revealedCorrectOptionID: String?
    private(set) var winner: Player?
    private(set) var playContext: PlayContext = .practice
    /// Genre chip on the riddle card; party games sync the real one.
    private(set) var activeGenreName = "Riddle Realm"
    /// The mode this party is playing (nil in practice, which is always
    /// plain Three Strikes).
    private(set) var activeModeSlug: String?
    /// Copilot's Curveball: the current question is in its early-reveal
    /// window — only the copilot's device may show it.
    private(set) var curveballPreviewActive = false
    /// Double or Nothing: the current (bonus) question is inside its
    /// wager lock-in window — no answers are accepted yet.
    private(set) var wagerWindowActive = false
    /// The wager the local player locked in for the window currently open
    /// (or just closed), so the UI can show "locked in" instead of asking
    /// again. Reset whenever the question index moves.
    private(set) var userSubmittedWager: Int?
    /// Team Relay: whose turn it is to answer for each squad (index 0/1).
    private(set) var teamTurnPlayerIDs: [UUID?] = [nil, nil]

    /// Increment-to-fire animation triggers observed by the screens.
    private(set) var confettiTrigger = 0
    private(set) var shakeTrigger = 0
    private(set) var reactionTrigger = 0
    private(set) var joinTrigger = 0

    /// Injectable for tests: uniform roll in [0, 1) deciding bot correctness.
    var botRoll: () -> Double = { Double.random(in: 0..<1) }
    /// Injectable for tests: delays collapse to zero under test.
    var revealDuration: Duration = .seconds(1.9)
    var spectatorAnswerDelay: Duration = .seconds(1.1)

    private let context: ModelContext
    private var advanceTask: Task<Void, Never>?

    /// Wired by the app when a real party forms.
    @ObservationIgnored weak var party: PartySession?
    @ObservationIgnored private var localPlayerID: UUID?

    // Diffing anchors for firing one-shot animations off synced snapshots.
    @ObservationIgnored private var lastSyncedRevealing = false
    @ObservationIgnored private var lastSyncedQuestionIndex = -1
    @ObservationIgnored private var lastSyncedPhase: PartyPhase = .lobby
    @ObservationIgnored private var lastSyncedEpoch = 0

    init(context: ModelContext) {
        self.context = context
        seatInitialParty()
    }

    /// True when this device is allowed to drive flow transitions (start,
    /// back-to-ride). Clients wait on the host.
    var canControlFlow: Bool { playContext != .partyClient }

    // MARK: - Party (Our Ride)

    var openSeatIndex: Int? {
        let taken = Set(players.map(\.seatIndex))
        return (0..<4).first { !taken.contains($0) }
    }

    var currentQuestion: TriviaQuestion? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    // MARK: - Copilot's Curveball

    var isCurveballMode: Bool { activeModeSlug == CopilotsCurveball.modeSlug }
    /// The current question carries the curveball twist (marked even after
    /// the preview window ends).
    var currentQuestionIsCurveball: Bool {
        isCurveballMode && CopilotsCurveball.isCurveballIndex(questionIndex)
    }
    var localPlayerIsCopilot: Bool { userPlayer?.role == .copilot }

    // MARK: - Herd Reveal / Team Relay / Double or Nothing

    var isHerdRevealMode: Bool { activeModeSlug == HerdReveal.modeSlug }
    var isTeamRelayMode: Bool { activeModeSlug == TeamRelay.modeSlug }
    var isDoubleOrNothingMode: Bool { activeModeSlug == DoubleOrNothing.modeSlug }
    var currentQuestionIsWager: Bool {
        isDoubleOrNothingMode && DoubleOrNothing.isWagerIndex(questionIndex)
    }
    /// Team Relay: is it the local player's turn to answer for their squad?
    /// True outside Team Relay so every other mode's answer gating is
    /// unaffected.
    var isMyTurnInTeamRelay: Bool {
        guard isTeamRelayMode, let localPlayerID else { return true }
        return teamTurnPlayerIDs.contains(localPlayerID)
    }
    func teamScore(_ team: Int) -> Int {
        players.filter { $0.teamIndex == team }.reduce(0) { $0 + $1.score }
    }

    /// Local player locks in a wager during Double or Nothing's window.
    func submitLocalWager(_ amount: Int) {
        guard playContext != .practice, wagerWindowActive, userSubmittedWager == nil else { return }
        userSubmittedWager = amount
        party?.submitLocalWager(amount: amount)
    }

    var userPlayer: Player? { players.first(where: \.isUser) }
    var alivePlayers: [Player] { players.filter { !$0.isOut } }
    /// Fuel left in the tank: full at question 1, empty when the round ends.
    var fuelRemaining: Double {
        questions.isEmpty ? 1 : 1 - Double(questionIndex) / Double(questions.count)
    }

    private func seatInitialParty() {
        // Blake (the user) drives; two simulated players are already aboard.
        let initial = [
            Player(name: "Blake", colorIndex: 0, seatIndex: 0, isUser: true),
            Player(name: "Scout", colorIndex: 1, seatIndex: 1, accuracy: 0.72),
            Player(name: "Turbo", colorIndex: 2, seatIndex: 2, accuracy: 0.58),
        ]
        initial.forEach(context.insert)
        players = initial
    }

    /// Fills the open seat with the 4th simulated player (practice only —
    /// real parties fill seats via synced claims).
    func joinOpenSeat() {
        guard playContext == .practice, let seat = openSeatIndex else { return }
        let joiner = Player(name: "Ziggy", colorIndex: 3, seatIndex: seat, accuracy: 0.5)
        context.insert(joiner)
        players.append(joiner)
        players.sort { $0.seatIndex < $1.seatIndex }
        joinTrigger += 1
    }

    /// The local player taps a seat in Our Ride (party mode: claims or
    /// moves; the host arbitrates conflicts).
    func requestSeat(_ seatIndex: Int) {
        guard playContext != .practice else { return }
        party?.claimSeat(seatIndex)
    }

    // MARK: - Round lifecycle

    func startGame(seed: UInt64? = nil, pack: [TriviaQuestion] = SeedQuestions.riddleRealm) {
        if playContext == .partyHost {
            party?.startTrip()
            return
        }
        guard playContext == .practice else { return }
        advanceTask?.cancel()
        for player in players {
            player.score = 0
            player.strikes = 0
            player.lastAnswerCorrect = nil
        }
        var generator: any RandomNumberGenerator = seed.map { SeededGenerator(seed: $0) }
            ?? SystemRandomNumberGenerator()
        questions = pack.map { $0.shufflingOptions(using: &generator) }
        questionIndex = 0
        winner = nil
        userPickedOptionID = nil
        revealedCorrectOptionID = nil
        turnState = .awaitingAnswer
        phase = .playing
        beginQuestionIfSpectating()
    }

    func backToRide() {
        if playContext == .partyHost {
            party?.returnToRide()
            return
        }
        guard playContext == .practice else { return }
        advanceTask?.cancel()
        phase = .ride
    }

    /// The user taps an answer.
    func submitUserAnswer(optionID: String) {
        guard phase == .playing,
              turnState == .awaitingAnswer,
              !curveballPreviewActive,
              !wagerWindowActive,
              isMyTurnInTeamRelay,
              userPickedOptionID == nil,
              let user = userPlayer, !user.isOut,
              let question = currentQuestion,
              question.options.contains(where: { $0.id == optionID })
        else { return }
        userPickedOptionID = optionID
        if playContext == .practice {
            resolveQuestion(userAnswerID: optionID)
        } else {
            // Locked in; the host resolves once the whole car has answered.
            party?.submitLocalAnswer(optionID: optionID)
        }
    }

    /// When the user is out, questions still resolve so the bots can finish
    /// the round while the user spectates.
    private func beginQuestionIfSpectating() {
        guard playContext == .practice, phase == .playing, turnState == .awaitingAnswer else { return }
        guard userPlayer == nil || userPlayer!.isOut else { return }
        let delay = spectatorAnswerDelay
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.resolveQuestion(userAnswerID: nil)
        }
    }

    private func resolveQuestion(userAnswerID: String?) {
        guard let question = currentQuestion else { return }

        // Majority-scored questions need everyone's actual pick, so bots
        // vote for a concrete option (botRoll doubles as the pick source);
        // authored questions keep the plain accuracy roll.
        var picks: [ObjectIdentifier: String] = [:]
        if let userAnswerID, let user = userPlayer {
            picks[ObjectIdentifier(user)] = userAnswerID
        }
        if question.isMajorityScored {
            for bot in alivePlayers where !bot.isUser {
                let index = min(Int(botRoll() * Double(question.options.count)),
                                question.options.count - 1)
                picks[ObjectIdentifier(bot)] = question.options[index].id
            }
        }
        let correctID = question.correctOptionID
            ?? MajorityVote.winningOptionID(votes: picks.values, options: question.options)
        revealedCorrectOptionID = correctID

        var userWasCorrect: Bool?
        for player in alivePlayers {
            let correct: Bool
            if player.isUser || question.isMajorityScored {
                guard let pick = picks[ObjectIdentifier(player)] else { continue }
                correct = pick == correctID
            } else {
                correct = botRoll() < player.accuracy
            }
            if player.isUser { userWasCorrect = correct }
            player.lastAnswerCorrect = correct
            if correct {
                player.score += 1
            } else {
                player.strikes += 1
            }
        }

        turnState = .revealing
        reactionTrigger += 1
        switch userWasCorrect {
        case true?: confettiTrigger += 1
        case false?: shakeTrigger += 1
        case nil: break
        }

        let delay = revealDuration
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.advance()
        }
    }

    private func advance() {
        guard phase == .playing else { return }
        for player in players {
            player.lastAnswerCorrect = nil
        }
        userPickedOptionID = nil
        revealedCorrectOptionID = nil

        let roundOver = alivePlayers.count <= 1 || questionIndex + 1 >= questions.count
        if roundOver {
            finishRound()
        } else {
            questionIndex += 1
            turnState = .awaitingAnswer
            beginQuestionIfSpectating()
        }
    }

    private func finishRound() {
        // Last one standing wins; if the tank ran dry (or everyone struck
        // out at once), highest score takes it, fewest strikes breaks ties.
        let pool = alivePlayers.isEmpty ? players : alivePlayers
        winner = pool.max { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.strikes != b.strikes { return a.strikes > b.strikes }
            return a.seatIndex > b.seatIndex
        }
        confettiTrigger += 1
        phase = .victory
    }

    /// Exposed so tests can await the scheduled reveal/advance step.
    func waitForPendingAdvance() async {
        await advanceTask?.value
    }

    // MARK: - Party mirroring

    /// Joins this engine to a live party: local taps route through the
    /// session, and synced snapshots become the rendered truth.
    func attachParty(_ party: PartySession, localPlayerID: UUID) {
        advanceTask?.cancel()
        self.party = party
        self.localPlayerID = localPlayerID
        lastSyncedRevealing = false
        lastSyncedQuestionIndex = -1
        lastSyncedPhase = .lobby
        lastSyncedEpoch = 0
    }

    /// The party is over — back to a fresh practice roster so the debug
    /// slice and a future party both start clean.
    func detachParty() {
        party = nil
        localPlayerID = nil
        playContext = .practice
        advanceTask?.cancel()
        removeAllPlayers()
        seatInitialParty()
        questions = []
        questionIndex = 0
        turnState = .awaitingAnswer
        userPickedOptionID = nil
        revealedCorrectOptionID = nil
        winner = nil
        activeGenreName = "Riddle Realm"
        activeModeSlug = nil
        wagerWindowActive = false
        userSubmittedWager = nil
        teamTurnPlayerIDs = [nil, nil]
        phase = .ride
    }

    /// Applies an authoritative snapshot from the host (every device,
    /// including the host itself, renders through this same path).
    func applyPartyState(_ state: PartyState) {
        guard let localPlayerID else { return }
        playContext = state.hostID == localPlayerID ? .partyHost : .partyClient

        syncPlayers(from: state)

        activeModeSlug = state.config.modeSlug
        let round = state.round
        if let round {
            if questions.map(\.id) != round.questions.map(\.id) {
                questions = round.questions
            }
            questionIndex = round.questionIndex
            turnState = round.revealing ? .revealing : .awaitingAnswer
            activeGenreName = round.genreName
            revealedCorrectOptionID = round.resolvedCorrectOptionID
            curveballPreviewActive = round.curveballPreview
            wagerWindowActive = round.wagerOpen
            teamTurnPlayerIDs = round.teamTurnPlayerID
            winner = round.winnerID.flatMap { id in players.first { $0.remoteID == id } }
        } else {
            questions = []
            questionIndex = 0
            turnState = .awaitingAnswer
            revealedCorrectOptionID = nil
            curveballPreviewActive = false
            wagerWindowActive = false
            teamTurnPlayerIDs = [nil, nil]
            winner = nil
        }

        // One-shot animation triggers, diffed off the previous snapshot.
        let localRow = players.first { $0.remoteID == localPlayerID }
        if let round, round.revealing, !lastSyncedRevealing {
            reactionTrigger += 1
            switch localRow?.lastAnswerCorrect {
            case true?: confettiTrigger += 1
            case false?: shakeTrigger += 1
            case nil: break
            }
        }
        if let round, round.questionIndex != lastSyncedQuestionIndex {
            userPickedOptionID = nil
            userSubmittedWager = nil
        }
        if state.epoch != lastSyncedEpoch, round?.revealing != true {
            // Host migration mid-question: in-flight answers died with the
            // old host, so unlock the local pick for a re-tap.
            userPickedOptionID = nil
            userSubmittedWager = nil
        }
        if state.phase == .victory, lastSyncedPhase != .victory {
            confettiTrigger += 1
        }
        if state.phase == .ride, lastSyncedPhase != .ride {
            userPickedOptionID = nil
        }

        lastSyncedRevealing = round?.revealing ?? false
        lastSyncedQuestionIndex = round?.questionIndex ?? -1
        lastSyncedPhase = state.phase
        lastSyncedEpoch = state.epoch

        switch state.phase {
        case .lobby, .ride: phase = .ride
        case .playing: phase = .playing
        case .victory: phase = .victory
        }
    }

    private func syncPlayers(from state: PartyState) {
        var rows = Dictionary(uniqueKeysWithValues: players.compactMap { row in
            row.remoteID.map { ($0, row) }
        })
        // Practice bots (no remoteID) never belong in a synced party.
        for stale in players where stale.remoteID == nil {
            context.delete(stale)
        }

        var synced: [Player] = []
        for remote in state.players {
            let row: Player
            if let existing = rows.removeValue(forKey: remote.id) {
                row = existing
            } else {
                row = Player(name: remote.name,
                             colorIndex: remote.colorIndex,
                             seatIndex: remote.seatIndex ?? Player.noSeat,
                             remoteID: remote.id)
                context.insert(row)
                joinTrigger += 1
            }
            row.name = remote.name
            row.colorIndex = remote.colorIndex
            row.seatIndex = remote.seatIndex ?? Player.noSeat
            row.isUser = remote.id == localPlayerID
            row.score = remote.score
            row.strikes = remote.strikes
            row.lastAnswerCorrect = remote.lastAnswerCorrect
            row.role = remote.role
            row.presence = remote.presence
            row.teamIndex = remote.teamIndex
            row.maxStrikesOverride = Elimination.maxStrikes(modeSlug: state.config.modeSlug)
            synced.append(row)
        }
        for (_, orphan) in rows {
            context.delete(orphan)
        }
        players = synced.sorted {
            let a = $0.seatIndex == Player.noSeat ? Int.max : $0.seatIndex
            let b = $1.seatIndex == Player.noSeat ? Int.max : $1.seatIndex
            if a != b { return a < b }
            return $0.name < $1.name
        }
    }

    private func removeAllPlayers() {
        for player in players {
            context.delete(player)
        }
        players = []
    }

    #if DEBUG
    /// Screenshot/dev shortcuts driven by launch arguments (see RootView).
    func debugApplyLaunchArguments(_ arguments: [String]) {
        if arguments.contains("-TTAutoStart") {
            joinOpenSeat()
            startGame(seed: 42)
        }
        if arguments.contains("-TTVictory") {
            joinOpenSeat()
            startGame(seed: 42)
            userPlayer?.score = 11
            finishRound()
        }
    }
    #endif
}

/// Deterministic generator so tests (and repeatable demos) can fix shuffles.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
