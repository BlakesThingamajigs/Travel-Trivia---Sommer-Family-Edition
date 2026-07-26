//
//  Travel_TriviaTests.swift
//  Travel TriviaTests
//
//  Three Strikes engine + seed content tests.
//

import Testing
import SwiftData
@testable import Travel_Trivia

@MainActor
private func makeEngine() throws -> GameEngine {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Player.self, configurations: configuration)
    let engine = GameEngine(context: container.mainContext)
    engine.revealDuration = .zero
    engine.spectatorAnswerDelay = .zero
    return engine
}

@MainActor
struct GameEngineTests {

    @Test func initialPartyHasThreePlayersAndAnOpenSeat() throws {
        let engine = try makeEngine()
        #expect(engine.players.count == 3)
        #expect(engine.openSeatIndex == 3)
        #expect(engine.userPlayer?.name == "Blake")
    }

    @Test func joiningOpenSeatAddsFourthPlayer() throws {
        let engine = try makeEngine()
        engine.joinOpenSeat()
        #expect(engine.players.count == 4)
        #expect(engine.openSeatIndex == nil)
        // A second tap can't over-fill the car
        engine.joinOpenSeat()
        #expect(engine.players.count == 4)
    }

    @Test func startGameDealsSixteenShuffledQuestions() throws {
        let engine = try makeEngine()
        engine.startGame(seed: 7)
        #expect(engine.phase == .playing)
        #expect(engine.questions.count == 16)
        for question in engine.questions {
            #expect(question.options.count == 6)
            #expect(question.options.contains { $0.id == question.correctOptionID })
        }
    }

    @Test func correctAnswerScoresAPoint() async throws {
        let engine = try makeEngine()
        engine.botRoll = { 0.99 }  // all bots miss
        engine.startGame(seed: 7)
        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: question.correctOptionID)
        #expect(engine.userPlayer?.score == 1)
        #expect(engine.userPlayer?.strikes == 0)
        #expect(engine.turnState == .revealing)
    }

    @Test func threeWrongAnswersEliminateThePlayer() async throws {
        let engine = try makeEngine()
        engine.botRoll = { 0.0 }  // all bots answer correctly — nobody else strikes out
        engine.startGame(seed: 7)

        for _ in 0..<3 {
            let question = try #require(engine.currentQuestion)
            let wrong = try #require(question.options.first { $0.id != question.correctOptionID })
            engine.submitUserAnswer(optionID: wrong.id)
            await engine.waitForPendingAdvance()
        }

        let user = try #require(engine.userPlayer)
        #expect(user.strikes == 3)
        #expect(user.isOut)
        // Round continues without the user; bots keep playing
        #expect(engine.phase == .playing)
    }

    @Test func lastPlayerStandingWinsImmediately() async throws {
        let engine = try makeEngine()
        engine.botRoll = { 0.99 }  // both bots miss every question
        engine.startGame(seed: 7)

        // Bots have 3 strikes each after 3 questions; user stays alive
        for _ in 0..<3 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: question.correctOptionID)
            await engine.waitForPendingAdvance()
        }

        #expect(engine.phase == .victory)
        #expect(engine.winner?.isUser == true)
        #expect(engine.winner?.score == 3)
    }

    @Test func exhaustingAllQuestionsCrownsHighestScorer() async throws {
        let engine = try makeEngine()
        engine.botRoll = { 0.4 }  // bots with accuracy > 0.4 always correct, others always wrong
        engine.startGame(seed: 7)

        var answered = 0
        while engine.phase == .playing, answered < 20 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: question.correctOptionID)
            await engine.waitForPendingAdvance()
            answered += 1
        }

        #expect(engine.phase == .victory)
        // The user answered every question correctly, so they must win
        #expect(engine.winner?.isUser == true)
        #expect(answered == 16)
    }

    @Test func backToRideResetsForANewRound() async throws {
        let engine = try makeEngine()
        engine.botRoll = { 0.99 }
        engine.startGame(seed: 7)
        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: question.correctOptionID)
        engine.backToRide()
        #expect(engine.phase == .ride)
        engine.startGame(seed: 9)
        #expect(engine.userPlayer?.score == 0)
        #expect(engine.userPlayer?.strikes == 0)
        #expect(engine.questionIndex == 0)
    }
}

struct SeedContentTests {

    @Test func seedPackHasSixteenWellFormedRiddles() {
        let questions = SeedQuestions.riddleRealm
        #expect(questions.count == 16)

        #expect(questions.filter { $0.difficulty == .easy }.count == 6)
        #expect(questions.filter { $0.difficulty == .medium }.count == 6)
        #expect(questions.filter { $0.difficulty == .hard }.count == 4)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(question.options.contains { $0.id == question.correctOptionID })
            #expect(Set(question.options.map(\.id)).count == 6)
            #expect(!question.prompt.isEmpty)
        }
        #expect(Set(questions.map(\.id)).count == 16)
    }
}
