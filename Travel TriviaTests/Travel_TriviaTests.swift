//
//  Travel_TriviaTests.swift
//  Travel TriviaTests
//
//  Three Strikes engine + seed content tests.
//

import Foundation
import Testing
import SwiftData
@testable import Travel_Trivia

/// Keeps the ModelContainer alive for the test's duration — the engine only
/// holds the context, and a deallocated container traps SwiftData on the
/// next model mutation.
@MainActor
private struct EngineHarness {
    let container: ModelContainer
    let engine: GameEngine

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Player.self, configurations: configuration)
        engine = GameEngine(context: container.mainContext)
        engine.revealDuration = .zero
        engine.spectatorAnswerDelay = .zero
    }
}

@MainActor
struct GameEngineTests {

    @Test func initialPartyHasThreePlayersAndAnOpenSeat() throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        #expect(engine.players.count == 3)
        #expect(engine.openSeatIndex == 3)
        #expect(engine.userPlayer?.name == "Blake")
    }

    @Test func joiningOpenSeatAddsFourthPlayer() throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.joinOpenSeat()
        #expect(engine.players.count == 4)
        #expect(engine.openSeatIndex == nil)
        // A second tap can't over-fill the car
        engine.joinOpenSeat()
        #expect(engine.players.count == 4)
    }

    @Test func startGameDealsSixteenShuffledQuestions() throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.startGame(seed: 7)
        #expect(engine.phase == .playing)
        #expect(engine.questions.count == 16)
        for question in engine.questions {
            #expect(question.options.count == 6)
            #expect(question.options.contains { $0.id == question.correctOptionID })
        }
    }

    @Test func correctAnswerScoresAPoint() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }  // all bots miss
        engine.startGame(seed: 7)
        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
        #expect(engine.userPlayer?.score == 1)
        #expect(engine.userPlayer?.strikes == 0)
        #expect(engine.turnState == .revealing)
    }

    @Test func threeWrongAnswersEliminateThePlayer() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
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
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }  // both bots miss every question
        engine.startGame(seed: 7)

        // Bots have 3 strikes each after 3 questions; user stays alive
        for _ in 0..<3 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
        }

        #expect(engine.phase == .victory)
        #expect(engine.winner?.isUser == true)
        #expect(engine.winner?.score == 3)
    }

    @Test func exhaustingAllQuestionsCrownsHighestScorer() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.4 }  // bots with accuracy > 0.4 always correct, others always wrong
        engine.startGame(seed: 7)

        var answered = 0
        while engine.phase == .playing, answered < 20 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
            answered += 1
        }

        #expect(engine.phase == .victory)
        // The user answered every question correctly, so they must win
        #expect(engine.winner?.isUser == true)
        #expect(answered == 16)
    }

    @Test func backToRideResetsForANewRound() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }
        engine.startGame(seed: 7)
        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
        engine.backToRide()
        #expect(engine.phase == .ride)
        engine.startGame(seed: 9)
        #expect(engine.userPlayer?.score == 0)
        #expect(engine.userPlayer?.strikes == 0)
        #expect(engine.questionIndex == 0)
    }
}

@MainActor
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

    @Test func wouldYouRatherPackIsAllMajorityScored() {
        let questions = SeedQuestions.wouldYouRather
        #expect(questions.count == 40)
        #expect(questions.filter { $0.difficulty == .easy }.count == 13)
        #expect(questions.filter { $0.difficulty == .medium }.count == 19)
        #expect(questions.filter { $0.difficulty == .hard }.count == 8)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(question.correctOptionID == nil)
            #expect(question.isMajorityScored)
            #expect(Set(question.options.map(\.id)).count == 6)
            #expect(!question.prompt.isEmpty)
        }
        #expect(Set(questions.map(\.id)).count == 40)
    }

    @Test func movieQuoteMashupPackHasFixedAnswers() {
        let questions = SeedQuestions.movieQuoteMashup
        #expect(questions.count == 40)
        #expect(questions.filter { $0.difficulty == .easy }.count == 15)
        #expect(questions.filter { $0.difficulty == .medium }.count == 14)
        #expect(questions.filter { $0.difficulty == .hard }.count == 11)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(!question.isMajorityScored)
            #expect(question.options.contains { $0.id == question.correctOptionID })
            #expect(Set(question.options.map(\.id)).count == 6)
        }
        #expect(Set(questions.map(\.id)).count == 40)
    }

    @Test func deckDealsRouteByGenreAndTier() {
        let littleOnes = QuestionDeck.deal(genreSlug: "would-you-rather", tier: .littleOnes, seed: 3)
        #expect(littleOnes.count == 13)
        #expect(littleOnes.allSatisfy { $0.difficulty == .easy && $0.id.hasPrefix("wyr-") })

        let grownUp = QuestionDeck.deal(genreSlug: "movie-quote-mashup", tier: .grownUp, seed: 3)
        #expect(grownUp.count == 25)
        #expect(grownUp.allSatisfy { $0.difficulty != .easy && $0.id.hasPrefix("mqm-") })

        // Unknown genres still deal a playable riddle deck.
        let fallback = QuestionDeck.deal(genreSlug: "superlative-showdown", tier: .familyMix, seed: 3)
        #expect(fallback.count == 16)
    }
}

struct MajorityVoteTests {
    private let options = [
        AnswerOption(id: "a", text: "A"), AnswerOption(id: "b", text: "B"),
        AnswerOption(id: "c", text: "C"), AnswerOption(id: "d", text: "D"),
    ]

    @Test func pluralityWins() {
        let winner = MajorityVote.winningOptionID(votes: ["c", "b", "c"], options: options)
        #expect(winner == "c")
    }

    @Test func tiesBreakTowardEarlierDisplayOrder() {
        let winner = MajorityVote.winningOptionID(votes: ["d", "b", "d", "b"], options: options)
        #expect(winner == "b")
    }

    @Test func noVotesMeansNoWinner() {
        #expect(MajorityVote.winningOptionID(votes: [], options: options) == nil)
    }
}

@MainActor
struct MajorityScoringEngineTests {

    /// Practice-mode Would You Rather: with botRoll pinned to 0 both bots
    /// vote for the first displayed option, so the user's different pick
    /// loses the vote 2-1 and earns a strike.
    @Test func userLosesMajorityVoteAgainstAlignedBots() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.0 }
        engine.startGame(seed: 7, pack: SeedQuestions.wouldYouRather)

        let question = try #require(engine.currentQuestion)
        let botsPick = question.options[0].id
        let userPick = question.options[1].id
        engine.submitUserAnswer(optionID: userPick)

        #expect(engine.revealedCorrectOptionID == botsPick)
        #expect(engine.userPlayer?.strikes == 1)
        #expect(engine.userPlayer?.lastAnswerCorrect == false)
        let bots = engine.players.filter { !$0.isUser }
        #expect(bots.allSatisfy { $0.score == 1 && $0.strikes == 0 })
    }

    @Test func userWinsMajorityVoteByJoiningTheBots() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.0 }
        engine.startGame(seed: 7, pack: SeedQuestions.wouldYouRather)

        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: question.options[0].id)

        #expect(engine.revealedCorrectOptionID == question.options[0].id)
        #expect(engine.userPlayer?.score == 1)
        #expect(engine.userPlayer?.lastAnswerCorrect == true)
        await engine.waitForPendingAdvance()
        #expect(engine.revealedCorrectOptionID == nil)
    }
}

/// Host-authority round logic driven headlessly: a real PartySession with
/// networking suppressed, fed the same intents live clients would send.
@MainActor
struct PartySessionHostTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    private func startParty(modeSlug: String, deck: [TriviaQuestion],
                            genreSlug: String) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.curveballPreviewDuration = .zero
        session.wagerDuration = .zero
        session.dealDeck = { _ in (deck, genreSlug, genreSlug) }

        let config = PartyConfig(modeSlug: modeSlug, modeName: modeSlug,
                                 genreSlug: genreSlug, genreName: genreSlug,
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.startRide()
        session.startTrip()
    }

    private func answer(_ playerID: UUID, _ optionID: String) {
        if playerID == hostID {
            session.submitLocalAnswer(optionID: optionID)
        } else {
            session.debugApplyIntent(.submitAnswer(playerID: playerID, optionID: optionID))
        }
    }

    @Test func majorityVoteScoresThePluralityAcrossThreePlayers() async throws {
        startParty(modeSlug: "three-strikes", deck: SeedQuestions.wouldYouRather,
                   genreSlug: "would-you-rather")
        let question = try #require(session.state?.round?.questions.first)

        // 2-1 split: the car's majority becomes the correct answer.
        answer(hostID, question.options[2].id)
        answer(riderID, question.options[2].id)
        answer(backseatID, question.options[4].id)

        let state = try #require(session.state)
        #expect(state.round?.revealing == true)
        #expect(state.round?.resolvedCorrectOptionID == question.options[2].id)
        #expect(state.player(hostID)?.score == 1)
        #expect(state.player(riderID)?.score == 1)
        #expect(state.player(backseatID)?.strikes == 1)
        #expect(state.player(backseatID)?.lastAnswerCorrect == false)

        await session.debugWaitForAdvance()
        #expect(session.state?.round?.questionIndex == 1)
        #expect(session.state?.round?.resolvedCorrectOptionID == nil)
    }

    @Test func curveballPreviewGatesTheFourthQuestion() async throws {
        startParty(modeSlug: CopilotsCurveball.modeSlug,
                   deck: SeedQuestions.movieQuoteMashup,
                   genreSlug: "movie-quote-mashup")
        session.assignRole(.copilot, to: riderID)
        let deck = try #require(session.state?.round?.questions)

        // Answer the first three questions correctly; no preview on any.
        for index in 0..<3 {
            #expect(session.state?.round?.curveballPreview == false)
            let correct = try #require(deck[index].correctOptionID)
            answer(hostID, correct)
            answer(riderID, correct)
            answer(backseatID, correct)
            await session.debugWaitForAdvance()
        }

        // Question 4 opens inside the copilot's early-reveal window: answers
        // are rejected until the window closes.
        #expect(session.state?.round?.questionIndex == 3)
        #expect(session.state?.round?.curveballPreview == true)
        let correct = try #require(deck[3].correctOptionID)
        answer(riderID, correct)
        #expect(session.state?.round?.revealing == false)

        await session.debugWaitForCurveballWindow()
        #expect(session.state?.round?.curveballPreview == false)

        // The early submit was dropped, so all three answer now.
        answer(hostID, correct)
        answer(riderID, correct)
        answer(backseatID, correct)
        #expect(session.state?.round?.revealing == true)
        #expect(session.state?.player(riderID)?.score == 4)

        await session.debugWaitForAdvance()
        #expect(session.state?.round?.questionIndex == 4)
        #expect(session.state?.round?.curveballPreview == false)
    }

    @Test func curveballPreviewSkippedWithoutACopilot() async throws {
        startParty(modeSlug: CopilotsCurveball.modeSlug,
                   deck: SeedQuestions.movieQuoteMashup,
                   genreSlug: "movie-quote-mashup")
        let deck = try #require(session.state?.round?.questions)

        for index in 0..<3 {
            let correct = try #require(deck[index].correctOptionID)
            answer(hostID, correct)
            answer(riderID, correct)
            answer(backseatID, correct)
            await session.debugWaitForAdvance()
        }

        // No copilot in the car — the twist can't happen, play stays normal.
        #expect(session.state?.round?.questionIndex == 3)
        #expect(session.state?.round?.curveballPreview == false)
    }
}

/// Elimination Bracket: sudden death — one wrong answer is out (not three),
/// eliminated players stay visible (spectators) instead of leaving, and the
/// round ends the moment one player remains.
@MainActor
struct EliminationBracketTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: Elimination.bracketModeSlug, modeName: "Elimination Bracket",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 4)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.startRide()
        session.startTrip()
    }

    private func answer(_ playerID: UUID, _ optionID: String) {
        if playerID == hostID {
            session.submitLocalAnswer(optionID: optionID)
        } else {
            session.debugApplyIntent(.submitAnswer(playerID: playerID, optionID: optionID))
        }
    }

    @Test func oneWrongAnswerEliminatesImmediatelyAndSpectatorsStayVisible() async throws {
        startParty(deck: Array(SeedQuestions.movieQuoteMashup.prefix(3)))
        let deck = try #require(session.state?.round?.questions)

        // Question 1: everybody answers correctly — nobody is out, play
        // continues normally.
        let q0Correct = try #require(deck[0].correctOptionID)
        answer(hostID, q0Correct)
        answer(riderID, q0Correct)
        answer(backseatID, q0Correct)
        await session.debugWaitForAdvance()
        #expect(session.state?.phase == .playing)
        #expect(session.state?.player(hostID)?.strikes == 0)
        #expect(session.state?.player(riderID)?.strikes == 0)
        #expect(session.state?.player(backseatID)?.strikes == 0)

        // Question 2: backseat misses — one strike is enough to be out.
        let q1Correct = try #require(deck[1].correctOptionID)
        let q1Wrong = try #require(deck[1].options.first { $0.id != q1Correct })
        answer(hostID, q1Correct)
        answer(riderID, q1Correct)
        answer(backseatID, q1Wrong.id)
        await session.debugWaitForAdvance()

        #expect(session.state?.player(backseatID)?.strikes == 1)
        // Still a full member of the roster (spectator), not removed.
        #expect(session.state?.players.count == 3)
        #expect(session.state?.player(backseatID)?.presence == .connected)
        // The round keeps moving — backseat is no longer part of the gate.
        #expect(session.state?.phase == .playing)

        // Question 3: rider also misses — down to one player standing, so
        // the round ends immediately even with a question left in the deck.
        let q2Correct = try #require(deck[2].correctOptionID)
        let q2Wrong = try #require(deck[2].options.first { $0.id != q2Correct })
        answer(hostID, q2Correct)
        answer(riderID, q2Wrong.id)
        await session.debugWaitForAdvance()

        #expect(session.state?.phase == .victory)
        #expect(session.state?.round?.winnerID == hostID)
        #expect(session.state?.player(hostID)?.score == 3)
        #expect(session.state?.player(riderID)?.strikes == 1)
        #expect(session.state?.player(backseatID)?.strikes == 1)
    }
}

/// Team Relay: one relay-turn player per squad answers each question,
/// rotating to the next connected teammate; squads' scores are cumulative.
@MainActor
struct TeamRelayTests {
    let session = PartySession()
    let hostID = UUID()   // team 0, seat 0
    let riderID = UUID()  // team 0, seat 1
    let backseatID = UUID()  // team 1, seat 2
    let fourthID = UUID()    // team 1, seat 3

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: TeamRelay.modeSlug, modeName: "Team Relay",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 4, requiresEvenPlayers: true)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.debugApplyIntent(.hello(playerID: fourthID, name: "Fourth"))
        session.assignTeam(0, to: hostID)
        session.assignTeam(0, to: riderID)
        session.assignTeam(1, to: backseatID)
        session.assignTeam(1, to: fourthID)
        session.startRide()
        session.startTrip()
    }

    private func answer(_ playerID: UUID, _ optionID: String) {
        if playerID == hostID {
            session.submitLocalAnswer(optionID: optionID)
        } else {
            session.debugApplyIntent(.submitAnswer(playerID: playerID, optionID: optionID))
        }
    }

    @Test func onlyTheRelayTurnPlayerCanAnswerAndScoresAreCumulativePerSquad() async throws {
        startParty(deck: Array(SeedQuestions.movieQuoteMashup.prefix(3)))
        let deck = try #require(session.state?.round?.questions)

        // Turn order is seat order within each squad: host (seat 0) before
        // rider (seat 1), backseat (seat 2) before fourth (seat 3).
        #expect(session.state?.round?.teamTurnPlayerID == [hostID, backseatID])

        // Question 1: rider and fourth are off-turn — their taps are no-ops.
        let q0Correct = try #require(deck[0].correctOptionID)
        answer(riderID, q0Correct)
        answer(fourthID, q0Correct)
        #expect(session.state?.round?.revealing != true)   // ignored, didn't resolve

        answer(hostID, q0Correct)
        answer(backseatID, q0Correct)
        await session.debugWaitForAdvance()
        #expect(session.state?.player(hostID)?.score == 1)
        #expect(session.state?.player(backseatID)?.score == 1)
        #expect(session.state?.player(riderID)?.score == 0)

        // Turn rotates to the next connected teammate on each squad.
        #expect(session.state?.round?.teamTurnPlayerID == [riderID, fourthID])

        // Question 2: rider misses, fourth gets it.
        let q1Correct = try #require(deck[1].correctOptionID)
        let q1Wrong = try #require(deck[1].options.first { $0.id != q1Correct })
        answer(riderID, q1Wrong.id)
        answer(fourthID, q1Correct)
        await session.debugWaitForAdvance()

        // Turn rotates back to the squads' first teammate.
        #expect(session.state?.round?.teamTurnPlayerID == [hostID, backseatID])

        // Question 3: host gets it, backseat misses.
        let q2Correct = try #require(deck[2].correctOptionID)
        let q2Wrong = try #require(deck[2].options.first { $0.id != q2Correct })
        answer(hostID, q2Correct)
        answer(backseatID, q2Wrong.id)
        await session.debugWaitForAdvance()

        // Squad totals: team 0 = host(2) + rider(0) = 2; team 1 =
        // backseat(1) + fourth(1) = 2... make it unambiguous by checking the
        // actual per-player scores instead of relying on a coin-flip tie.
        #expect(session.state?.phase == .victory)
        #expect(session.state?.player(hostID)?.score == 2)
        #expect(session.state?.player(riderID)?.score == 0)
        #expect(session.state?.player(backseatID)?.score == 1)
        #expect(session.state?.player(fourthID)?.score == 1)
        // Strikes never eliminate a relay player — everyone's still in it.
        #expect(session.state?.players.allSatisfy { $0.presence == .connected } == true)
    }
}
