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

        // sound-fx-guess got real bundled content in the audio-genres
        // session — family-mix allows all 3 difficulties, so the whole
        // 10-clip pack deals (no genre has an empty tier gap for these 3
        // audio genres; each pack's easy/medium/hard split covers all of
        // familyMix, littleOnes, and grownUp with something playable).
        let soundFX = QuestionDeck.deal(genreSlug: "sound-fx-guess", tier: .familyMix, seed: 3)
        #expect(soundFX.count == 10)
        #expect(soundFX.allSatisfy { $0.hasAudioClip })

        // An unrecognized genre slug still deals a playable riddle deck —
        // every real genre now has bundled content, so this exercises the
        // fallback path the old test used sound-fx-guess for.
        let fallback = QuestionDeck.deal(genreSlug: "not-a-real-genre", tier: .familyMix, seed: 3)
        #expect(fallback.count == 16)
    }

    /// Genre Batch 2: six new fixed-answer packs (see SeedQuestions.swift).
    /// Shape-checks every pack the same way the earlier seeded genres are
    /// checked, plus a Globe-Trotter-Clues-specific check that its 3
    /// escalating clues are joined into one multi-line prompt.
    @Test func genreBatch2PacksAreWellFormed() {
        let packs: [(String, String, [TriviaQuestion])] = [
            ("gtc", "globe-trotter-clues", SeedQuestions.globeTrotterClues),
            ("myth", "mythical-creatures-legends", SeedQuestions.mythicalCreaturesLegends),
            ("weird", "random-acts-of-weird-facts", SeedQuestions.randomActsOfWeirdFacts),
            ("super", "superlative-showdown", SeedQuestions.superlativeShowdown),
            ("time", "time-machine", SeedQuestions.timeMachine),
            ("pop", "pop-culture-time-capsule", SeedQuestions.popCultureTimeCapsule),
        ]
        for (prefix, slug, questions) in packs {
            #expect(questions.count == 30, "\(slug) should have 30 questions")
            for question in questions {
                #expect(question.options.count == 6)
                #expect(question.options.contains { $0.id == question.correctOptionID })
                #expect(Set(question.options.map(\.id)).count == 6)
                #expect(!question.prompt.isEmpty)
                #expect(question.id.hasPrefix("\(prefix)-"))
            }
            #expect(Set(questions.map(\.id)).count == 30)
            #expect(SeedQuestions.packs[slug]?.count == 30)
        }
    }

    @Test func globeTrotterCluesPromptsJoinThreeClues() {
        let questions = SeedQuestions.globeTrotterClues
        for question in questions {
            // 3 escalating clues joined with "\n" -> exactly 2 newlines.
            #expect(question.prompt.filter { $0 == "\n" }.count == 2)
        }
    }

    /// The 3 audio genres (Animal Sounds Safari, Sound FX Guess, Name That
    /// Tune): every question needs a real bundled clip AND its attribution
    /// — losing either would either silently drop audio or violate the CC
    /// licenses the clips ship under.
    @Test func audioGenrePacksHaveClipsAndAttribution() {
        let packs: [(String, [TriviaQuestion])] = [
            ("animal-sounds-safari", AudioSeedQuestions.animalSoundsSafari),
            ("sound-fx-guess", AudioSeedQuestions.soundFXGuess),
            ("name-that-tune", AudioSeedQuestions.nameThatTune),
        ]
        for (slug, questions) in packs {
            #expect(!questions.isEmpty, "\(slug) should have real bundled questions")
            for question in questions {
                #expect(question.hasAudioClip, "\(question.id) is missing its clip")
                #expect(question.attribution?.isEmpty == false, "\(question.id) is missing attribution")
                #expect(question.options.count == 6)
                #expect(question.options.contains { $0.id == question.correctOptionID })
                #expect(Set(question.options.map(\.id)).count == 6)
                // Every clip must actually resolve inside the app bundle —
                // catches a renamed/missing resource at test time instead
                // of a silent no-op at play time.
                #expect(AudioClipLibrary.url(for: question, genreSlug: slug) != nil,
                        "\(question.id)'s clip \(question.mediaFileName ?? "nil") isn't bundled")
            }
            #expect(SeedQuestions.packs[slug]?.count == questions.count)
        }
    }
}

/// Genre Batch 2: plays one question of each new fixed-answer genre through
/// the practice engine, confirming the deck loads (content displays) and a
/// correct answer scores a point (content scores) — the same pattern the
/// engine tests above use for the earlier seeded genres.
@MainActor
struct GenreBatch2EngineTests {
    private func playsAndScores(pack: [TriviaQuestion]) async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }
        engine.startGame(seed: 7, pack: pack)
        #expect(engine.questions.count == 30)
        let question = try #require(engine.currentQuestion)
        engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
        #expect(engine.userPlayer?.score == 1)
        #expect(engine.turnState == .revealing)
    }

    @Test func globeTrotterCluesRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.globeTrotterClues)
    }

    @Test func mythicalCreaturesLegendsRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.mythicalCreaturesLegends)
    }

    @Test func randomActsOfWeirdFactsRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.randomActsOfWeirdFacts)
    }

    @Test func superlativeShowdownRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.superlativeShowdown)
    }

    @Test func timeMachineRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.timeMachine)
    }

    @Test func popCultureTimeCapsuleRoundScoresCorrectly() async throws {
        try await playsAndScores(pack: SeedQuestions.popCultureTimeCapsule)
    }

    /// A wrong answer should strike instead of score — confirms the whole
    /// resolve path (not just the always-correct case) works for the new
    /// content.
    @Test func globeTrotterCluesWrongAnswerStrikes() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }
        engine.startGame(seed: 7, pack: SeedQuestions.globeTrotterClues)
        let question = try #require(engine.currentQuestion)
        let wrong = try #require(question.options.first { $0.id != question.correctOptionID })
        engine.submitUserAnswer(optionID: wrong.id)
        #expect(engine.userPlayer?.score == 0)
        #expect(engine.userPlayer?.strikes == 1)
        #expect(engine.revealedCorrectOptionID == question.correctOptionID)
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

/// Herd Reveal: any genre's normally-authored questions, scored by whoever
/// matched the car's *majority pick* — not whoever was objectively right.
@MainActor
struct HerdRevealTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: HerdReveal.modeSlug, modeName: "Herd Reveal",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 3)
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

    @Test func popularWrongAnswerScoresCorrectAndTheObjectivelyRightMinorityLoses() async throws {
        startParty(deck: SeedQuestions.movieQuoteMashup)
        let question = try #require(session.state?.round?.questions.first)
        let objectivelyCorrect = try #require(question.correctOptionID)
        let popularButWrong = try #require(question.options.first { $0.id != objectivelyCorrect })

        // 2-1 split: the majority is objectively wrong per the question's
        // authored answer, but Herd Reveal scores the vote, not the truth.
        answer(hostID, popularButWrong.id)
        answer(riderID, popularButWrong.id)
        answer(backseatID, objectivelyCorrect)

        let state = try #require(session.state)
        #expect(state.round?.resolvedCorrectOptionID == popularButWrong.id)
        #expect(state.round?.resolvedCorrectOptionID != objectivelyCorrect)
        #expect(state.player(hostID)?.score == 1)
        #expect(state.player(hostID)?.lastAnswerCorrect == true)
        #expect(state.player(riderID)?.score == 1)
        // Backseat picked the *actually* correct answer and still strikes
        // out, because it lost the popular vote.
        #expect(state.player(backseatID)?.strikes == 1)
        #expect(state.player(backseatID)?.lastAnswerCorrect == false)
    }
}

/// Double or Nothing: every 4th question is a wager round — players lock in
/// a wager against their current score before it opens, correct doubles it
/// (net +wager), wrong subtracts it, floored at zero.
@MainActor
struct DoubleOrNothingTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.wagerDuration = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: DoubleOrNothing.modeSlug, modeName: "Double or Nothing",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
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

    private func wager(_ playerID: UUID, _ amount: Int) {
        if playerID == hostID {
            session.submitLocalWager(amount: amount)
        } else {
            session.debugApplyIntent(.submitWager(playerID: playerID, amount: amount))
        }
    }

    @Test func wagerWinDoublesAndWagerLossFloorsAtZero() async throws {
        startParty(deck: Array(SeedQuestions.movieQuoteMashup.prefix(4)))
        let deck = try #require(session.state?.round?.questions)

        // Questions 1-3 answer correctly, normal +1 scoring: everyone banks
        // a score of 3 heading into the wager round.
        for index in 0..<3 {
            let correct = try #require(deck[index].correctOptionID)
            answer(hostID, correct)
            answer(riderID, correct)
            answer(backseatID, correct)
            await session.debugWaitForAdvance()
        }
        #expect(session.state?.player(hostID)?.score == 3)
        #expect(session.state?.player(riderID)?.score == 3)
        #expect(session.state?.player(backseatID)?.score == 3)

        // Question 4 (index 3) is the wager round: answers are rejected
        // until every wager is locked in / the window times out.
        #expect(session.state?.round?.questionIndex == 3)
        #expect(session.state?.round?.wagerOpen == true)
        let q3Correct = try #require(deck[3].correctOptionID)
        answer(hostID, q3Correct)
        #expect(session.state?.round?.revealing != true)   // rejected — window's still open

        wager(hostID, 3)      // going all-in
        wager(riderID, 3)     // also all-in, but about to miss
        // backseat doesn't wager at all (defaults to 0 — no gain, no loss).
        await session.debugWaitForWagerWindow()
        #expect(session.state?.round?.wagerOpen == false)

        let q3Wrong = try #require(deck[3].options.first { $0.id != q3Correct })
        answer(hostID, q3Correct)    // wins the wager: 3 + 3 = 6
        answer(riderID, q3Wrong.id)  // loses the wager: 3 - 3 = 0, floored
        answer(backseatID, q3Correct) // no wager locked in — no change either way

        let state = try #require(session.state)
        #expect(state.player(hostID)?.score == 6)
        #expect(state.player(riderID)?.score == 0)
        #expect(state.player(backseatID)?.score == 3)
        // Strikes aren't touched by wager settlement — it's not an
        // elimination risk.
        #expect(state.player(hostID)?.strikes == 0)
        #expect(state.player(riderID)?.strikes == 0)
        // Wager clears once settled.
        #expect(state.player(hostID)?.pendingWager == nil)
        #expect(state.player(riderID)?.pendingWager == nil)
    }
}

/// Host-partition demotion: a network-partitioned-but-alive host that spots
/// a higher-epoch advertisement of its own party (a promoted backup host
/// out in the mesh) should concede rather than keep advertising a stale
/// epoch forever. This only exercises the *decision* headlessly — it does
/// not exercise the real rejoin-over-Multipeer path, which needs an actual
/// network partition to test for real.
@MainActor
struct HostPartitionTests {
    @Test func stalerHostConcedesToAHigherEpochRivalAd() throws {
        let session = PartySession()
        session.suppressesNetworking = true
        let hostID = UUID()
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "riddle-realm", genreName: "Riddle Realm",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        #expect(session.isHost == true)

        session.debugSimulateRivalHostAd(epoch: 1)   // higher than our epoch 0
        #expect(session.isHost == false)
        #expect(session.status == .searching)
    }

    @Test func sameOrLowerEpochRivalIsIgnored() throws {
        let session = PartySession()
        session.suppressesNetworking = true
        let hostID = UUID()
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "riddle-realm", genreName: "Riddle Realm",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")

        session.debugSimulateRivalHostAd(epoch: 0)   // same epoch, no promotion happened
        #expect(session.isHost == true)

        session.debugSimulateRivalHostAd(epoch: 0, name: "Someone Else's Party", code: "9999")
        #expect(session.isHost == true)
    }
}
