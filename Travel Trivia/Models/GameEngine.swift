//
//  GameEngine.swift
//  Travel Trivia
//
//  Three Strikes round logic for the single-device slice. Every alive
//  player answers each question "simultaneously" — the user by tapping,
//  simulated players by an accuracy roll — matching the real multiplayer
//  semantics the Multipeer version will have.
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

    private(set) var phase: Phase = .ride
    private(set) var players: [Player] = []
    private(set) var questions: [TriviaQuestion] = []
    private(set) var questionIndex = 0
    private(set) var turnState: TurnState = .awaitingAnswer
    private(set) var userPickedOptionID: String?
    private(set) var winner: Player?

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

    init(context: ModelContext) {
        self.context = context
        seatInitialParty()
    }

    // MARK: - Party (Our Ride)

    var openSeatIndex: Int? {
        let taken = Set(players.map(\.seatIndex))
        return (0..<4).first { !taken.contains($0) }
    }

    var currentQuestion: TriviaQuestion? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
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

    /// Fills the open seat with the 4th simulated player.
    func joinOpenSeat() {
        guard let seat = openSeatIndex else { return }
        let joiner = Player(name: "Ziggy", colorIndex: 3, seatIndex: seat, accuracy: 0.5)
        context.insert(joiner)
        players.append(joiner)
        players.sort { $0.seatIndex < $1.seatIndex }
        joinTrigger += 1
    }

    // MARK: - Round lifecycle

    func startGame(seed: UInt64? = nil) {
        advanceTask?.cancel()
        for player in players {
            player.score = 0
            player.strikes = 0
            player.lastAnswerCorrect = nil
        }
        var generator: any RandomNumberGenerator = seed.map { SeededGenerator(seed: $0) }
            ?? SystemRandomNumberGenerator()
        questions = SeedQuestions.riddleRealm.map { $0.shufflingOptions(using: &generator) }
        questionIndex = 0
        winner = nil
        userPickedOptionID = nil
        turnState = .awaitingAnswer
        phase = .playing
        beginQuestionIfSpectating()
    }

    func backToRide() {
        advanceTask?.cancel()
        phase = .ride
    }

    /// The user taps an answer.
    func submitUserAnswer(optionID: String) {
        guard phase == .playing,
              turnState == .awaitingAnswer,
              let user = userPlayer, !user.isOut,
              let question = currentQuestion,
              question.options.contains(where: { $0.id == optionID })
        else { return }
        userPickedOptionID = optionID
        resolveQuestion(userAnswerID: optionID)
    }

    /// When the user is out, questions still resolve so the bots can finish
    /// the round while the user spectates.
    private func beginQuestionIfSpectating() {
        guard phase == .playing, turnState == .awaitingAnswer else { return }
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

        var userWasCorrect: Bool?
        for player in alivePlayers {
            let correct: Bool
            if player.isUser {
                guard let userAnswerID else { continue }
                correct = userAnswerID == question.correctOptionID
                userWasCorrect = correct
            } else {
                correct = botRoll() < player.accuracy
            }
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
