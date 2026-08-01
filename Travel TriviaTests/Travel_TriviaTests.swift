//
//  Travel_TriviaTests.swift
//  Travel TriviaTests
//
//  Three Strikes engine + seed content tests.
//

import Foundation
import Testing
import SwiftData
import AVFoundation
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
        // Round 2 (2026-07-27) grew Riddle Realm from 16 to 46 questions;
        // round 3 (2026-08-01) grew it again to 76.
        #expect(engine.questions.count == 76)
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

    /// The round-length floor keeps sudden death from ending a round after
    /// just a couple of quick strike-outs: the lone survivor keeps playing
    /// solo against the deck until `RoundLength.minQuestionsBeforeSuddenDeath`
    /// questions have been asked.
    @Test func lastPlayerStandingKeepsPlayingSoloUntilTheRoundLengthFloor() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.99 }  // both bots miss every question
        engine.startGame(seed: 7)

        // Bots have 3 strikes each after 3 questions, but the round isn't
        // over yet — the user is the lone survivor and keeps playing.
        for _ in 0..<3 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
        }
        #expect(engine.phase == .playing)
        #expect(engine.questionIndex == 3)

        // Keep answering solo until the floor is reached.
        while engine.phase == .playing {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
        }

        #expect(engine.phase == .victory)
        #expect(engine.winner?.isUser == true)
        #expect(engine.winner?.score == RoundLength.minQuestionsBeforeSuddenDeath)
        #expect(engine.questionIndex == RoundLength.minQuestionsBeforeSuddenDeath - 1)
    }

    @Test func exhaustingAllQuestionsCrownsHighestScorer() async throws {
        let harness = try EngineHarness()
        let engine = harness.engine
        engine.botRoll = { 0.4 }  // bots with accuracy > 0.4 always correct, others always wrong
        engine.startGame(seed: 7)

        var answered = 0
        // Nobody strikes out at this bot accuracy, so the round only ends by
        // exhausting the whole Riddle Realm deck — round 2 (2026-07-27) grew
        // that from 16 to 46 questions, round 3 (2026-08-01) grew it again to
        // 76, so the safety cap and final count both need to cover the full 76.
        while engine.phase == .playing, answered < 80 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
            answered += 1
        }

        #expect(engine.phase == .victory)
        // The user answered every question correctly, so they must win
        #expect(engine.winner?.isUser == true)
        #expect(answered == 76)
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
        // Round 2 (2026-07-27) added 30 more riddles (17-46) on top of the
        // original 16; round 3 (2026-08-01) added 30 more (47-76). Counts
        // below reflect the combined pack.
        #expect(questions.count == 76)

        #expect(questions.filter { $0.difficulty == .easy }.count == 29)
        #expect(questions.filter { $0.difficulty == .medium }.count == 32)
        #expect(questions.filter { $0.difficulty == .hard }.count == 15)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(question.options.contains { $0.id == question.correctOptionID })
            #expect(Set(question.options.map(\.id)).count == 6)
            #expect(!question.prompt.isEmpty)
        }
        #expect(Set(questions.map(\.id)).count == 76)
    }

    @Test func wouldYouRatherPackIsAllMajorityScored() {
        let questions = SeedQuestions.wouldYouRather
        // Round 2 (2026-07-27) added 30 more (41-70) on top of the original
        // 40. Round 3 (2026-08-01) added 60 more (71-130): a "round 3" batch
        // of 30 that was drafted back on 2026-07-28 but never actually
        // seeded until now, plus the separate "round 4" batch of 30.
        #expect(questions.count == 130)
        #expect(questions.filter { $0.difficulty == .easy }.count == 48)
        #expect(questions.filter { $0.difficulty == .medium }.count == 62)
        #expect(questions.filter { $0.difficulty == .hard }.count == 20)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(question.correctOptionID == nil)
            #expect(question.isMajorityScored)
            #expect(Set(question.options.map(\.id)).count == 6)
            #expect(!question.prompt.isEmpty)
        }
        #expect(Set(questions.map(\.id)).count == 130)
    }

    @Test func movieQuoteMashupPackHasFixedAnswers() {
        let questions = SeedQuestions.movieQuoteMashup
        // Round 2 (2026-07-27) added 30 more (41-70) on top of the original
        // 40. Round 3 (2026-08-01) added 30 more (71-100).
        #expect(questions.count == 100)
        #expect(questions.filter { $0.difficulty == .easy }.count == 36)
        #expect(questions.filter { $0.difficulty == .medium }.count == 41)
        #expect(questions.filter { $0.difficulty == .hard }.count == 23)

        for question in questions {
            #expect(question.options.count == 6)
            #expect(!question.isMajorityScored)
            #expect(question.options.contains { $0.id == question.correctOptionID })
            #expect(Set(question.options.map(\.id)).count == 6)
        }
        #expect(Set(questions.map(\.id)).count == 100)
    }

    @Test func deckDealsRouteByGenreAndTier() {
        // Round 3 (2026-08-01) grew both packs again; QuestionDeck.deal
        // returns every tier-matching question (no fixed round length), so
        // these counts track the packs' new easy/non-easy splits directly:
        // would-you-rather is now 130 total (48 easy / 62 medium / 20 hard),
        // movie-quote-mashup is now 100 total (36 easy / 41 medium / 23 hard).
        let littleOnes = QuestionDeck.deal(genreSlug: "would-you-rather", tier: .littleOnes, seed: 3)
        #expect(littleOnes.count == 48)
        #expect(littleOnes.allSatisfy { $0.difficulty == .easy && $0.id.hasPrefix("wyr-") })

        let grownUp = QuestionDeck.deal(genreSlug: "movie-quote-mashup", tier: .grownUp, seed: 3)
        #expect(grownUp.count == 64)
        #expect(grownUp.allSatisfy { $0.difficulty != .easy && $0.id.hasPrefix("mqm-") })

        // sound-fx-guess got real bundled content in the audio-genres
        // session, then grew again in the audio-genre-expansion pass
        // (2026-07-28: 10 -> 23 clips) — family-mix allows all 3
        // difficulties, so the whole pack deals (no genre has an empty
        // tier gap for these 3 audio genres; each pack's easy/medium/hard
        // split covers all of familyMix, littleOnes, and grownUp with
        // something playable).
        let soundFX = QuestionDeck.deal(genreSlug: "sound-fx-guess", tier: .familyMix, seed: 3)
        #expect(soundFX.count == 23)
        #expect(soundFX.allSatisfy { $0.hasAudioClip })

        // An unrecognized genre slug still deals a playable riddle deck —
        // every real genre now has bundled content, so this exercises the
        // fallback path the old test used sound-fx-guess for. Round 2
        // (2026-07-27) grew Riddle Realm from 16 to 46 questions; round 3
        // (2026-08-01) grew it again to 76.
        let fallback = QuestionDeck.deal(genreSlug: "not-a-real-genre", tier: .familyMix, seed: 3)
        #expect(fallback.count == 76)
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
        // Round 2 (2026-07-27) added 30 more questions to each of these 6
        // genres on top of the original 30 (60 each); round 3 (2026-08-01)
        // added 30 more on top of that, so 90 each now.
        for (prefix, slug, questions) in packs {
            #expect(questions.count == 90, "\(slug) should have 90 questions")
            for question in questions {
                #expect(question.options.count == 6)
                #expect(question.options.contains { $0.id == question.correctOptionID })
                #expect(Set(question.options.map(\.id)).count == 6)
                #expect(!question.prompt.isEmpty)
                #expect(question.id.hasPrefix("\(prefix)-"))
            }
            #expect(Set(questions.map(\.id)).count == 90)
            #expect(SeedQuestions.packs[slug]?.count == 90)
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
                guard let url = AudioClipLibrary.url(for: question, genreSlug: slug) else {
                    Issue.record("\(question.id)'s clip \(question.mediaFileName ?? "nil") isn't bundled")
                    continue
                }
                // Not just "the file exists" — actually decode it through the
                // same AVAudioPlayer AudioDirector.playClip uses in production,
                // so a corrupt/mistranscoded clip fails here instead of
                // silently no-op-ing (AudioDirector's catch swallows the
                // error) in a real game.
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    #expect(player.duration > 0, "\(question.id)'s clip decoded but has zero duration")
                } catch {
                    Issue.record("\(question.id)'s clip \(url.lastPathComponent) failed to decode: \(error)")
                }
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
        // Round 2 (2026-07-27) grew each of these packs from 30 to 60;
        // round 3 (2026-08-01) grew them again to 90.
        #expect(engine.questions.count == 90)
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

    /// Regression: a solo-hosted party (nobody else ever joined) starts
    /// with exactly 1 player, which used to satisfy the sudden-death
    /// condition trivially after the very first question in every mode,
    /// not just Elimination Bracket. It should play the whole deck instead.
    @Test func soloHostedPartyDoesNotEndAfterOneQuestion() async throws {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        let deck = SeedQuestions.wouldYouRather
        session.dealDeck = { _ in (deck, "would-you-rather", "would-you-rather") }
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "would-you-rather", genreName: "would-you-rather",
                                 difficulty: .familyMix, minPlayers: 1)
        session.host(partyName: "Solo", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.startRide()
        session.startTrip()

        session.submitLocalAnswer(optionID: try #require(session.state?.round?.questions.first?.options.first?.id))
        await session.debugWaitForAdvance()

        #expect(session.state?.phase == .playing)
        #expect(session.state?.round?.questionIndex == 1)
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

    /// Regression: the Lobby let a host start Team Relay with nobody
    /// assigned to a squad, which silently played through the whole deck
    /// via `holdIfNobodyCanAnswer`'s "nobody connected" fallback — every
    /// question skipped, no one ever able to answer. `meetsPlayerRequirement`
    /// now also requires every connected rider to have a team, with both
    /// teams non-empty.
    @Test func meetsPlayerRequirementFailsUntilEveryoneHasATeam() throws {
        session.suppressesNetworking = true
        let config = PartyConfig(modeSlug: TeamRelay.modeSlug, modeName: "Team Relay",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 4, requiresEvenPlayers: true)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.debugApplyIntent(.hello(playerID: fourthID, name: "Fourth"))

        #expect(session.state?.meetsPlayerRequirement == false,
                "4 connected riders but nobody's on a team yet")

        session.assignTeam(0, to: hostID)
        session.assignTeam(0, to: riderID)
        #expect(session.state?.meetsPlayerRequirement == false,
                "everyone assigned so far is on the same single team")

        session.assignTeam(1, to: backseatID)
        session.assignTeam(1, to: fourthID)
        #expect(session.state?.meetsPlayerRequirement == true,
                "all 4 connected riders now split across both teams")
    }
}

/// Would You Rather: purely social — every non-driver seat votes, a pie
/// chart's worth of vote tally is recorded, nobody scores, and the round
/// ends with no winner declared. Replaces the old Herd Reveal mode.
@MainActor
struct WouldYouRatherModeTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()
    let driverID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, WouldYouRatherMode.genreSlug, WouldYouRatherMode.genreName) }
        let config = PartyConfig(modeSlug: WouldYouRatherMode.modeSlug, modeName: "Would You Rather",
                                 genreSlug: WouldYouRatherMode.genreSlug, genreName: WouldYouRatherMode.genreName,
                                 difficulty: .familyMix, minPlayers: 3)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.debugApplyIntent(.hello(playerID: driverID, name: "Driver"))
        session.assignRole(.pilot, to: driverID)
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

    @Test func votesAreTalliedAndNobodyScoresOrStrikesOut() async throws {
        startParty(deck: SeedQuestions.wouldYouRather)
        let question = try #require(session.state?.round?.questions.first)

        // 2-1 split among the non-driver seats.
        answer(hostID, question.options[2].id)
        answer(riderID, question.options[2].id)
        answer(backseatID, question.options[4].id)

        let state = try #require(session.state)
        #expect(state.round?.revealing == true)
        // Purely social: no correct answer is ever resolved…
        #expect(state.round?.resolvedCorrectOptionID == nil)
        // …but the real vote distribution is still recorded for the chart.
        #expect(state.round?.voteCounts[question.options[2].id] == 2)
        #expect(state.round?.voteCounts[question.options[4].id] == 1)
        // Nobody scores, nobody strikes out — this mode is scoreless.
        #expect(state.player(hostID)?.score == 0)
        #expect(state.player(riderID)?.score == 0)
        #expect(state.player(backseatID)?.score == 0)
        #expect(state.player(backseatID)?.strikes == 0)
    }

    @Test func driverIsExcludedFromTheAnswerGateOnEveryQuestion() async throws {
        startParty(deck: SeedQuestions.wouldYouRather)
        let question = try #require(session.state?.round?.questions.first)

        // The driver's tap is a no-op — never counted, never blocks the
        // reveal from happening once the other three seats answer.
        answer(driverID, question.options[0].id)
        answer(hostID, question.options[0].id)
        answer(riderID, question.options[0].id)
        answer(backseatID, question.options[0].id)

        let state = try #require(session.state)
        #expect(state.round?.revealing == true)
        #expect(state.player(driverID)?.score == 0)
        #expect(state.round?.voteCounts.values.reduce(0, +) == 3)
    }

    @Test func roundEndsWithNoWinnerAndAVoteHistoryForTheRecap() async throws {
        let deck = Array(SeedQuestions.wouldYouRather.prefix(2))
        startParty(deck: deck)

        for question in deck {
            answer(hostID, question.options[0].id)
            answer(riderID, question.options[0].id)
            answer(backseatID, question.options[1].id)
            await session.debugWaitForAdvance()
        }

        let state = try #require(session.state)
        #expect(state.phase == .victory)
        #expect(state.round?.winnerID == nil)
        #expect(state.round?.voteHistory.count == deck.count)
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

/// Leave Game: a deliberate mid-game exit, distinct from the accidental-
/// dropout grace-period/reconnection system — the leaver is marked gone
/// immediately, and the rest of the party keeps playing.
@MainActor
struct LeaveGameTests {
    let hostID = UUID()
    let riderID = UUID()   // first joiner: becomes the backup host
    let backseatID = UUID()

    private func startParty(_ session: PartySession, deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "would-you-rather", "would-you-rather") }
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "would-you-rather", genreName: "would-you-rather",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.startRide()
        session.startTrip()
    }

    /// A non-host's deliberate leave (`.goodbye`) skips the accidental-
    /// dropout grace window entirely — marked `.left` in one step, not
    /// `.dropped` waiting on a timer — and the round keeps moving without
    /// them.
    @Test func nonHostLeavingMidGameIsMarkedGoneImmediatelyAndRoundContinues() async throws {
        let session = PartySession()
        startParty(session, deck: SeedQuestions.wouldYouRather)
        #expect(session.state?.backupHostID == riderID, "first joiner should be the designated backup")

        session.debugApplyIntent(.goodbye(playerID: backseatID))

        let leftPlayer = try #require(session.state?.player(backseatID))
        #expect(leftPlayer.presence == .left, "goodbye should mark the player gone immediately, not .dropped")
        #expect(leftPlayer.seatIndex == nil)

        // The round continues: host and rider can still answer without
        // waiting on the departed player. Would You Rather is majority-
        // scored (no authored correct answer), so both just pick the same
        // option to resolve the question.
        let question = try #require(session.state?.round?.questions.first)
        let pick = try #require(question.options.first).id
        session.submitLocalAnswer(optionID: pick)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: pick))
        await session.debugWaitForAdvance()
        #expect(session.state?.round?.questionIndex == 1, "round should have advanced without the departed player blocking it")
    }

    /// A host's deliberate leave mid-game hands off to the backup right
    /// away — the backup doesn't have to wait to notice the host went
    /// quiet, unlike a real accidental drop.
    @Test func hostLeavingMidGamePromotesBackupImmediately() throws {
        let hostSession = PartySession()
        startParty(hostSession, deck: SeedQuestions.wouldYouRather)
        let snapshot = try #require(hostSession.state)
        #expect(snapshot.backupHostID == riderID)

        // The backup's own session, brought to the same known state the
        // real sync would have given it.
        let riderSession = PartySession()
        riderSession.suppressesNetworking = true
        riderSession.localPlayerID = riderID
        riderSession.debugReceiveState(snapshot)
        #expect(riderSession.isHost == false)

        riderSession.debugSimulateHostLeaving()

        #expect(riderSession.isHost == true, "the backup should promote itself immediately")
        #expect(riderSession.state?.hostID == riderID)
        #expect(riderSession.state?.epoch == snapshot.epoch + 1)
        // The round in flight survives the handoff instead of resetting.
        #expect(riderSession.state?.round?.questionIndex == snapshot.round?.questionIndex)
    }
}

/// The car seats 6 now (was 4) — Multipeer already supports more players
/// than that, so this is really just confirming `PartyWire.maxPlayers`,
/// seat assignment, and a full round all actually work at the new cap,
/// not just that the seat art fits 6 boxes on screen.
@MainActor
struct SixSeatPartyTests {
    @Test func sixPlayersJoinSeatAndPlayAFullRoundTogether() async throws {
        let session = PartySession()
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (SeedQuestions.riddleRealm, "riddle-realm", "Riddle Realm") }

        let hostID = UUID()
        let riderIDs = (0..<5).map { _ in UUID() }
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "riddle-realm", genreName: "Riddle Realm",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Full Car", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        for (i, id) in riderIDs.enumerated() {
            session.debugApplyIntent(.hello(playerID: id, name: "Rider \(i)"))
        }
        #expect(session.state?.players.count == 6, "all 6 should be admitted, none turned away at the cap")

        let allIDs = [hostID] + riderIDs
        for (seat, id) in allIDs.enumerated() {
            session.debugApplyIntent(.requestSeat(playerID: id, seatIndex: seat))
        }
        #expect(Set(session.state?.players.compactMap(\.seatIndex) ?? []) == Set(0..<6),
                "every player should land in a distinct one of the 6 seats")

        session.startRide()
        session.startTrip()
        #expect(session.state?.phase == .playing)

        var answered = 0
        // This test's stubbed dealDeck hands back the full Riddle Realm pack
        // (not the real app's truncated QuestionDeck.deal), so the safety
        // cap has to cover the whole pack — 76 questions as of round 3
        // (2026-08-01).
        while session.state?.phase == .playing, answered < 80 {
            let question = try #require(session.state?.round?.questions[
                session.state?.round?.questionIndex ?? 0])
            let correct = try #require(question.correctOptionID)
            session.submitLocalAnswer(optionID: correct)
            for id in riderIDs {
                session.debugApplyIntent(.submitAnswer(playerID: id, optionID: correct))
            }
            await session.debugWaitForAdvance()
            answered += 1
        }

        #expect(session.state?.phase == .victory, "a full round with all 6 players should reach victory")
        let players = try #require(session.state?.players)
        // Nobody's assigned the pilot role in this test, so all 6 qualify
        // for every All Aboard question (every 5th) — everyone answers
        // correctly, so the whole-car group bonus lands every time too.
        let allAboardHits = answered / AllAboard.cadence
        let expectedScore = answered + allAboardHits * AllAboard.groupBonus
        #expect(players.allSatisfy { $0.score == expectedScore })
    }
}

/// Badges & My Garage progression — local-only SwiftData persistence
/// (ProgressStore) that's meant to survive relaunches on this device.
@MainActor
struct ProgressStoreTests {

    /// The core "relaunch and check it's still there" guarantee, done at
    /// the SwiftData layer: a badge earned through one ModelContainer must
    /// still be there when a brand-new container/context opens the same
    /// on-disk store — exactly what happens across a real app relaunch.
    @Test func awardedBadgePersistsAcrossANewContainer() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "progress-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: storeURL)
        let playerID = UUID()

        let container1 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress1 = ProgressStore(context: container1.mainContext, playerID: playerID)
        #expect(progress1.earnedBadgeIDs.isEmpty)
        #expect(progress1.award(BadgeCatalog.perfectRoundID) == true)
        // Idempotent: earning the same badge again shouldn't re-fire or duplicate.
        #expect(progress1.award(BadgeCatalog.perfectRoundID) == false)

        let container2 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress2 = ProgressStore(context: container2.mainContext, playerID: playerID)
        #expect(progress2.earnedBadgeIDs.contains(BadgeCatalog.perfectRoundID))
    }

    /// Regression: a device that earned "mode-mastery-herd-reveal" before
    /// Herd Reveal was replaced by Would You Rather must load that save
    /// without crashing or losing the badge — see
    /// BadgeCatalog.retiredModeMasteryBadges.
    @Test func preExistingHerdRevealBadgeLoadsWithoutCrashingAndStaysResolvable() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "progress-retired-badge-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: storeURL)
        let playerID = UUID()

        // Simulate a pre-migration save: earn the badge directly, as if it
        // happened back when Herd Reveal still existed in the catalog.
        let container1 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        container1.mainContext.insert(EarnedBadge(playerID: playerID, badgeID: BadgeCatalog.modeMasteryID("herd-reveal")))
        try container1.mainContext.save()

        // A fresh launch (today's catalog, which no longer has Herd Reveal)
        // must load this save cleanly.
        let container2 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress2 = ProgressStore(context: container2.mainContext, playerID: playerID)
        #expect(progress2.earnedBadgeIDs.contains(BadgeCatalog.modeMasteryID("herd-reveal")))

        let catalog = ContentCatalog()
        // Not in the active catalog (mode is gone)…
        #expect(BadgeCatalog.allBadges(catalog: catalog).contains { $0.id == BadgeCatalog.modeMasteryID("herd-reveal") } == false)
        // …but still resolvable for display, exactly what GarageView's
        // badgesTab needs to render the row instead of crashing or
        // silently dropping it.
        let definition = BadgeCatalog.definition(for: BadgeCatalog.modeMasteryID("herd-reveal"), catalog: catalog)
        #expect(definition?.title == "Herd Reveal Champ")

        // Would You Rather itself never generates a mode-mastery badge (no
        // win condition) — confirm it's excluded, not just Herd Reveal's
        // absence.
        #expect(BadgeCatalog.allBadges(catalog: catalog).contains { $0.id == BadgeCatalog.modeMasteryID(WouldYouRatherMode.modeSlug) } == false)
    }

    /// Expanded avatar customization (hair/face mark/head shape): equipping
    /// each new category persists across a relaunch exactly like the
    /// original hat/accessory/sticker categories do.
    @Test func expandedAvatarCategoriesEquipAndPersist() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "progress-avatar-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: storeURL)
        let playerID = UUID()

        let container1 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress1 = ProgressStore(context: container1.mainContext, playerID: playerID)
        #expect(progress1.avatarLoadout.headShapeID == "shape-round", "new fields should default sensibly on a fresh row")
        #expect(progress1.avatarLoadout.hairID == "hair-none")
        #expect(progress1.avatarLoadout.faceMarkID == "face-none")

        progress1.equipHair("hair-mohawk")  // free item, no purchase needed
        progress1.awardCoins(45 + 40)  // shape-square (45) + face-mustache (40)
        #expect(progress1.purchase(CosmeticCatalog.item("shape-square", in: CosmeticCatalog.headShapes)) == true)
        progress1.equipHeadShape("shape-square")
        #expect(progress1.purchase(CosmeticCatalog.item("face-mustache", in: CosmeticCatalog.faceMarks)) == true)
        progress1.equipFaceMark("face-mustache")

        let container2 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress2 = ProgressStore(context: container2.mainContext, playerID: playerID)
        #expect(progress2.avatarLoadout.hairID == "hair-mohawk")
        #expect(progress2.avatarLoadout.headShapeID == "shape-square")
        #expect(progress2.avatarLoadout.faceMarkID == "face-mustache")
        #expect(progress2.isUnlocked(CosmeticCatalog.item("shape-square", in: CosmeticCatalog.headShapes)))
    }

    /// Narrator persona pick is local-only (not party-wide, per-player like
    /// avatar cosmetics) and must survive a relaunch the same way.
    @Test func narratorPersonaPersistsAcrossANewContainer() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "progress-narrator-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: storeURL)
        let playerID = UUID()

        let container1 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress1 = ProgressStore(context: container1.mainContext, playerID: playerID)
        #expect(progress1.narratorVoicePreference.persona == nil, "fresh row defaults to system voice")
        progress1.setNarratorPersona(.hypeMan)

        let container2 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress2 = ProgressStore(context: container2.mainContext, playerID: playerID)
        #expect(progress2.narratorVoicePreference.persona == .hypeMan)

        progress2.setNarratorPersona(nil)
        #expect(progress2.narratorVoicePreference.persona == nil, "clears back to system default")
    }

    @Test func finishingARoundAwardsGenreCompletionAndPerfectRound() async throws {
        let engineHarness = try EngineHarness()
        let engine = engineHarness.engine
        let progressConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        let progressContainer = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                                   configurations: progressConfig)
        let progress = ProgressStore(context: progressContainer.mainContext, playerID: UUID())
        engine.progress = progress

        // Every bot answers correctly too, so nobody (including the user)
        // takes a strike for the whole round — the Perfect Round precondition.
        engine.botRoll = { 0 }
        engine.startGame(seed: 7)

        var answered = 0
        // engine.startGame(seed:) defaults to the full Riddle Realm pack,
        // which round 2 (2026-07-27) grew to 46 questions and round 3
        // (2026-08-01) grew again to 76 — the safety cap has to cover the
        // whole pack for this to reach victory.
        while engine.phase == .playing, answered < 80 {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: question.correctOptionID ?? question.options[0].id)
            await engine.waitForPendingAdvance()
            answered += 1
        }

        #expect(engine.phase == .victory)
        #expect(progress.earnedBadgeIDs.contains(BadgeCatalog.genreCompletionID("riddle-realm")))
        #expect(progress.earnedBadgeIDs.contains(BadgeCatalog.perfectRoundID))
    }

    /// Winning a practice round (no mode/difficulty picker, so Three
    /// Strikes at the Family Mix rate) pays out base×familyMix coins, and
    /// badges no longer gate cosmetic unlocks — only the coin price does.
    @Test func winningARoundAwardsCoinsAndBadgesNoLongerGateCosmetics() async throws {
        let engineHarness = try EngineHarness()
        let engine = engineHarness.engine
        let progressConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        let progressContainer = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                                   configurations: progressConfig)
        let progress = ProgressStore(context: progressContainer.mainContext, playerID: UUID())
        engine.progress = progress

        engine.botRoll = { 0.99 }  // both bots miss every question, user is the lone survivor
        engine.startGame(seed: 7)
        // The round-length floor keeps this from ending right after the
        // bots strike out — the user plays solo to the floor.
        while engine.phase == .playing {
            let question = try #require(engine.currentQuestion)
            engine.submitUserAnswer(optionID: try #require(question.correctOptionID))
            await engine.waitForPendingAdvance()
        }

        #expect(engine.phase == .victory)
        #expect(progress.coinBalance == CoinPayout.coinsForWin(modeSlug: "three-strikes", difficulty: .familyMix))

        // The round win also earns badges (genre completion, mode mastery,
        // perfect round) — badges keep working as pure achievements, they
        // just no longer gate this cosmetic.
        #expect(progress.earnedBadgeIDs.contains(BadgeCatalog.perfectRoundID))
        let partyHat = CosmeticCatalog.item("hat-party", in: CosmeticCatalog.hats)
        #expect(progress.isUnlocked(partyHat) == false)
        #expect(progress.purchase(partyHat) == false, "shouldn't be affordable off a single fast win")
        // Top up from further wins to afford it, same as a real player would.
        progress.awardCoins(partyHat.price)
        let startingBalance = progress.coinBalance
        #expect(progress.purchase(partyHat) == true)
        #expect(progress.isUnlocked(partyHat) == true)
        #expect(progress.coinBalance == startingBalance - partyHat.price)
        // Buying the same item twice doesn't double-charge.
        #expect(progress.purchase(partyHat) == false)
        #expect(progress.coinBalance == startingBalance - partyHat.price)
    }

    /// Coins and purchases persist across a relaunch exactly like badges do.
    @Test func coinsAndPurchasesPersistAcrossANewContainer() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appending(path: "progress-coins-test-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(url: storeURL)
        let playerID = UUID()

        let container1 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress1 = ProgressStore(context: container1.mainContext, playerID: playerID)
        progress1.awardCoins(100)
        let bowtie = CosmeticCatalog.item("acc-bowtie", in: CosmeticCatalog.accessories)
        #expect(progress1.purchase(bowtie) == true)

        let container2 = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                            configurations: configuration)
        let progress2 = ProgressStore(context: container2.mainContext, playerID: playerID)
        #expect(progress2.coinBalance == 100 - bowtie.price)
        #expect(progress2.isUnlocked(bowtie) == true)
    }
}

/// Genre selection routing to real question content, exercised through the
/// actual production wiring (`AppModel.wireParty`'s `dealDeck` closure ->
/// `QuestionDeck.deal`), not a test-mocked `dealDeck` like every other
/// PartySession test in this file uses. That mocking is exactly why a
/// wiring-layer regression here could go undetected by the rest of the
/// suite: `QuestionDeck.deal` itself was already covered and correct, but
/// nothing exercised the closure that actually resolves *which* genre gets
/// passed to it in a real hosted party.
@MainActor
struct GenreRoutingTests {
    /// Every real genre's picked slug reaches the real dealt deck, for
    /// every one of the 12 bundled genres, driven through `AppModel.hostParty`
    /// exactly as Create Game does — not a shortcut around it.
    @Test func everyGenreDealsItsOwnContentThroughTheRealHostFlow() throws {
        let expectedPrefix: [String: String] = [
            "riddle-realm": "riddle-",
            "would-you-rather": "wyr-",
            "movie-quote-mashup": "mqm-",
            "globe-trotter-clues": "gtc-",
            "mythical-creatures-legends": "myth-",
            "random-acts-of-weird-facts": "weird-",
            "superlative-showdown": "super-",
            "time-machine": "time-",
            "pop-culture-time-capsule": "pop-",
            "animal-sounds-safari": "animalSoundsSafari-",
            "sound-fx-guess": "soundFXGuess-",
            "name-that-tune": "nameThatTune-",
        ]
        #expect(expectedPrefix.count == ContentCatalog.bundledGenres.count,
                "every bundled genre needs a prefix mapping here or this test isn't the full scan it claims to be")

        for genre in ContentCatalog.bundledGenres {
            let prefix = try #require(expectedPrefix[genre.slug])
            let container = try ModelContainer(for: Player.self,
                                               configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let engine = GameEngine(context: container.mainContext)
            let profile = LocalProfile(defaults: UserDefaults(suiteName: "genre-routing-test-\(UUID())")!)
            let progressContainer = try ModelContainer(
                for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let progress = ProgressStore(context: progressContainer.mainContext, playerID: profile.playerID)
            let party = PartySession()
            party.suppressesNetworking = true
            party.revealDuration = .zero
            let app = AppModel(engine: engine, profile: profile, catalog: ContentCatalog(),
                               party: party, progress: progress)

            let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                     genreSlug: genre.slug, genreName: genre.displayName,
                                     difficulty: .familyMix, minPlayers: 1)
            app.hostParty(partyName: "Genre Check", code: "1234", config: config)
            party.startRide()
            // Exercise the exact call the real "Start the Trip" button makes
            // (GameEngine.startGame(), no arguments) rather than reaching
            // into PartySession directly — that's the call site the bug
            // report named, so this needs to prove *that* path is sound,
            // including that `engine.playContext` is really `.partyHost` by
            // the time a real host taps the button (it's set synchronously
            // by `applyPartyState` off `host()`'s own `commit()`, before
            // `hostParty()` even returns, so there's no race to worry about
            // in practice — but assert it directly since that's the crux).
            #expect(engine.playContext == .partyHost)
            engine.startGame()

            let dealt = try #require(party.state?.round?.questions)
            #expect(!dealt.isEmpty, "\(genre.slug): dealt deck should not be empty")
            #expect(dealt.allSatisfy { $0.id.hasPrefix(prefix) },
                    "\(genre.slug): expected every question id to start with '\(prefix)' but got \(dealt.map(\.id))")
            #expect(engine.activeGenreSlug == genre.slug,
                    "\(genre.slug): GameEngine's synced activeGenreSlug should match the picked genre")
        }
    }
}

/// Nav-prompt audio pausing (Part E follow-up): built against
/// `AVAudioSession.interruptionNotification`, the real signal iOS delivers
/// to every app — Maps/Waze included — when another app takes the audio
/// session. Never exercised against a live Maps prompt before (not
/// triggerable in the simulator), so this posts the same notification the
/// OS itself posts for a real interruption, with the same userInfo shape,
/// rather than calling AudioDirector's pause/resume internals directly.
@MainActor
struct AudioDirectorInterruptionTests {
    @Test func realOSInterruptionNotificationPausesAndResumesNarration() async throws {
        let profile = LocalProfile(defaults: UserDefaults(suiteName: "audio-director-test-\(UUID())")!)
        let progressContainer = try ModelContainer(for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self, CoinWallet.self, PurchasedCosmetic.self, NarratorVoicePreference.self,
                                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let progress = ProgressStore(context: progressContainer.mainContext, playerID: profile.playerID)
        let director = AudioDirector(profile: profile, progress: progress)

        director.speak("Testing nav prompt pausing")
        #expect(director.isSpeaking == true)
        #expect(director.isInterrupted == false)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        // The handler hops to the main actor via Task { @MainActor in ... };
        // give it a beat to run before asserting.
        try await Task.sleep(for: .milliseconds(50))
        #expect(director.isInterrupted == true)

        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        try await Task.sleep(for: .milliseconds(50))
        #expect(director.isInterrupted == false)
    }
}

/// A synthetic stand-in for `AVSpeechSynthesisVoice` — real Enhanced/
/// Premium voices are an optional on-device download (see NarratorVoice.swift),
/// not guaranteed present on the machine running these tests, so the
/// persona-matching logic is exercised against hand-built voice traits
/// instead of whatever happens to be installed here.
private struct FakeSpeechVoice: SpeechVoiceDescribing {
    var identifier: String
    var name: String
    var language: String
    var gender: AVSpeechSynthesisVoiceGender
    var quality: AVSpeechSynthesisVoiceQuality
}

/// The 4-persona narrator voice matching logic (NarratorVoiceCatalog): each
/// persona resolves to a distinct on-device Enhanced/Premium voice scored
/// by language/gender fit, and a persona with no eligible voice left is
/// reported as needing a download rather than silently falling back.
@MainActor
struct NarratorVoiceTests {
    @Test func fourPersonasResolveToFourDistinctVoicesFromARichPool() {
        let pool: [FakeSpeechVoice] = [
            .init(identifier: "gb-premium-male", name: "Arthur", language: "en-GB", gender: .male, quality: .premium),
            .init(identifier: "us-enhanced-female", name: "Nora", language: "en-US", gender: .female, quality: .enhanced),
            .init(identifier: "us-premium-male-1", name: "Tom", language: "en-US", gender: .male, quality: .premium),
            .init(identifier: "us-enhanced-male-2", name: "Evan", language: "en-US", gender: .male, quality: .enhanced),
        ]
        let resolved = NarratorVoiceCatalog.resolve(from: pool)
        #expect(resolved.count == 4)
        // Every persona lands on a different identifier — nobody doubles up.
        #expect(Set(resolved.values.map(\.identifier)).count == 4)
        // Tour Guide is language-locked to British English.
        #expect(resolved[.tourGuide]?.identifier == "gb-premium-male")
        #expect(resolved[.coPilot]?.identifier == "us-enhanced-female")
    }

    @Test func personaWithNoEligibleVoiceReportsNeedsDownload() {
        // No en-GB voice anywhere in the pool — Tour Guide has nothing to
        // claim, language-locked as it is, even though English voices exist.
        let pool: [FakeSpeechVoice] = [
            .init(identifier: "us-premium-male", name: "Tom", language: "en-US", gender: .male, quality: .premium),
        ]
        let resolved = NarratorVoiceCatalog.resolve(from: pool)
        #expect(resolved[.tourGuide] == nil)
        if case .needsDownload = NarratorVoiceCatalog.availability(for: .tourGuide, resolved: resolved) {
            // expected
        } else {
            Issue.record("Tour Guide should need downloading with no en-GB voice available")
        }
        if case .available = NarratorVoiceCatalog.availability(for: .coPilot, resolved: resolved) {
            // expected — falls back to the one en-US voice present
        } else {
            Issue.record("Co-Pilot should resolve to the available en-US voice")
        }
    }

    @Test func defaultQualityVoicesAreNeverEligible() {
        // Only a Compact/default-quality voice available — every persona
        // should report needs-download rather than silently using it.
        let pool: [FakeSpeechVoice] = [
            .init(identifier: "us-default", name: "Samantha", language: "en-US", gender: .female, quality: .default),
        ]
        let resolved = NarratorVoiceCatalog.resolve(from: pool)
        #expect(resolved.isEmpty)
    }

    @Test func emptyPoolLeavesEveryPersonaNeedingDownload() {
        let resolved = NarratorVoiceCatalog.resolve(from: [FakeSpeechVoice]())
        for persona in NarratorPersona.allCases {
            #expect(resolved[persona] == nil)
        }
    }
}

/// The round-length floor (`RoundLength.minQuestionsBeforeSuddenDeath`):
/// sudden death can't end a real party round before that many questions
/// have been asked, even in Elimination Bracket where one wrong answer
/// normally eliminates outright.
@MainActor
struct RoundLengthFloorTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: Elimination.bracketModeSlug, modeName: "Elimination Bracket",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.startRide()
        session.startTrip()
    }

    @Test func soleSurvivorKeepsPlayingSoloUntilTheFloorEvenInEliminationBracket() async throws {
        // A deck comfortably longer than the floor.
        startParty(deck: SeedQuestions.movieQuoteMashup)
        let deck = try #require(session.state?.round?.questions)

        // Rider misses the very first question — one strike is enough to be
        // out in Elimination Bracket — but the round must not end yet.
        let q0Correct = try #require(deck[0].correctOptionID)
        let q0Wrong = try #require(deck[0].options.first { $0.id != q0Correct })
        session.submitLocalAnswer(optionID: q0Correct)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: q0Wrong.id))
        await session.debugWaitForAdvance()

        #expect(session.state?.player(riderID)?.strikes == 1)
        #expect(session.state?.phase == .playing,
                "the host is now the lone survivor, but the round shouldn't end before the floor")

        // The host keeps answering solo up to the floor.
        while session.state?.phase == .playing {
            let index = try #require(session.state?.round?.questionIndex)
            let correct = try #require(deck[index].correctOptionID)
            session.submitLocalAnswer(optionID: correct)
            await session.debugWaitForAdvance()
        }

        #expect(session.state?.phase == .victory)
        #expect(session.state?.round?.winnerID == hostID)
        // 15 base points (one per question) plus the All Aboard group bonus
        // on every 5th question the host (the lone remaining answerer,
        // never assigned the pilot role in this test) gets right solo —
        // questions 5, 10, 15 (indices 4, 9, 14) — 3 hits × groupBonus.
        let allAboardHits = RoundLength.minQuestionsBeforeSuddenDeath / AllAboard.cadence
        let expectedScore = RoundLength.minQuestionsBeforeSuddenDeath + allAboardHits * AllAboard.groupBonus
        #expect(session.state?.player(hostID)?.score == expectedScore)
    }
}

/// Victory → Play Another Round: same party/seats, cumulative scores across
/// rounds, host picks (or keeps) the mode/genre/difficulty for the next one.
@MainActor
struct PlayAnotherRoundTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.startRide()
        session.startTrip()
    }

    private func playToVictory(deck: [TriviaQuestion]) async {
        for question in deck {
            guard session.state?.phase == .playing else { break }
            let correct = question.correctOptionID ?? question.options[0].id
            session.submitLocalAnswer(optionID: correct)
            session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
            await session.debugWaitForAdvance()
        }
    }

    @Test func scoresCarryOverCumulativelyAcrossTwoRounds() async throws {
        let deck = Array(SeedQuestions.movieQuoteMashup.prefix(3))
        startParty(deck: deck)
        await playToVictory(deck: deck)

        #expect(session.state?.phase == .victory)
        let scoreAfterRoundOne = try #require(session.state?.player(hostID)?.score)
        #expect(scoreAfterRoundOne == deck.count)

        let sameConfig = try #require(session.state?.config)
        session.playAnotherRound(config: sameConfig)

        #expect(session.state?.phase == .playing)
        #expect(session.state?.round?.questionIndex == 0)
        // Cumulative, not reset: round 2 starts from round 1's score.
        #expect(session.state?.player(hostID)?.score == scoreAfterRoundOne)
        #expect(session.state?.player(hostID)?.strikes == 0)
        // Same seats by default — nobody got bumped or reshuffled.
        #expect(session.state?.player(hostID)?.seatIndex == 0)
        #expect(session.state?.player(riderID)?.seatIndex == 1)

        await playToVictory(deck: deck)
        #expect(session.state?.phase == .victory)
        #expect(session.state?.player(hostID)?.score == scoreAfterRoundOne + deck.count)
    }

    @Test func hostCanPickADifferentModeAndGenreForTheNextRound() async throws {
        let deck = Array(SeedQuestions.movieQuoteMashup.prefix(3))
        startParty(deck: deck)
        await playToVictory(deck: deck)

        let riddles = SeedQuestions.riddleRealm
        session.dealDeck = { _ in (riddles, "riddle-realm", "Riddle Realm") }
        let newConfig = PartyConfig(modeSlug: CopilotsCurveball.modeSlug, modeName: "Copilot's Curveball",
                                    genreSlug: "riddle-realm", genreName: "Riddle Realm",
                                    difficulty: .familyMix, minPlayers: 2)
        session.playAnotherRound(config: newConfig)

        #expect(session.state?.phase == .playing)
        #expect(session.state?.config.modeSlug == CopilotsCurveball.modeSlug)
        #expect(session.state?.round?.genreSlug == "riddle-realm")
        #expect(session.state?.round?.questions.first?.id == riddles.first?.id)
    }
}

/// Host-only Pause & Reshuffle Seats: available only in the gap between
/// questions, freezes the round without touching scores/strikes, and
/// resumes at the exact question that would have played next.
@MainActor
struct PauseAndReshuffleSeatsTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()

    private func startParty(deck: [TriviaQuestion]) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: "three-strikes", modeName: "Three Strikes",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 2)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.requestSeat(playerID: hostID, seatIndex: 0))
        session.debugApplyIntent(.requestSeat(playerID: riderID, seatIndex: 1))
        session.startRide()
        session.startTrip()
    }

    @Test func isANoOpMidAnswerAndOnlyWorksDuringTheRevealGap() async throws {
        startParty(deck: SeedQuestions.movieQuoteMashup)
        // Nobody's answered yet — this is mid-question, not the reveal gap.
        session.pauseAndReshuffleSeats()
        #expect(session.state?.phase == .playing, "pausing mid-answer should be a no-op")

        let question = try #require(session.state?.round?.questions.first)
        let correct = try #require(question.correctOptionID)
        session.submitLocalAnswer(optionID: correct)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
        #expect(session.state?.round?.revealing == true)

        // Now we're in the gap: the reveal is showing, the next question
        // hasn't opened yet.
        session.pauseAndReshuffleSeats()
        #expect(session.state?.phase == .ride)
        #expect(session.state?.round == nil, "the round moves into pausedRound, not round")
    }

    @Test func resumeContinuesFromTheExactNextQuestionWithNoScoreChange() async throws {
        startParty(deck: SeedQuestions.movieQuoteMashup)
        let deck = try #require(session.state?.round?.questions)
        let q0Correct = try #require(deck[0].correctOptionID)
        session.submitLocalAnswer(optionID: q0Correct)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: q0Correct))
        #expect(session.state?.round?.revealing == true)

        let scoreBeforePause = session.state?.player(hostID)?.score
        session.pauseAndReshuffleSeats()
        #expect(session.state?.phase == .ride)

        // Move to fresh seats while paused — score/strikes stay put. (A
        // straight two-way swap needs a vacating step first since a seat
        // claim is rejected while still occupied; moving to two other free
        // seats exercises the same "seats changed during the pause" path
        // without that pre-existing seat-claim wrinkle.)
        session.debugApplyIntent(.requestSeat(playerID: hostID, seatIndex: 2))
        session.debugApplyIntent(.requestSeat(playerID: riderID, seatIndex: 3))
        #expect(session.state?.player(hostID)?.score == scoreBeforePause)

        session.resumeFromPause()

        // The next question served matches what would have played next
        // before the pause: question index 1, not a repeat of question 0.
        #expect(session.state?.phase == .playing)
        #expect(session.state?.round?.questionIndex == 1)
        #expect(session.state?.round?.revealing == false)
        #expect(session.state?.pausedRound == nil)
        #expect(session.state?.player(hostID)?.score == scoreBeforePause,
                "resuming shouldn't itself change anyone's score")
        #expect(session.state?.player(hostID)?.seatIndex == 2)
        #expect(session.state?.player(riderID)?.seatIndex == 3)

        // Play continues normally from here.
        let q1Correct = try #require(deck[1].correctOptionID)
        session.submitLocalAnswer(optionID: q1Correct)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: q1Correct))
        #expect(session.state?.round?.revealing == true)
        #expect(session.state?.player(hostID)?.score == (scoreBeforePause ?? 0) + 1)
    }
}

/// "All Aboard" bonus questions (`AllAboard.cadence` = every 5th question):
/// every non-driver seat answers independently instead of the round's usual
/// single/relay answerer, with a whole-car group bonus on top of everyone's
/// normal point if every participant got it right together. Covers Three
/// Strikes (baseline mechanics + driver exclusion), Elimination Bracket
/// (eliminated players stay full spectators), and Team Relay (both squads
/// answer, turn rotation resumes unaffected afterward) for real against the
/// production `PartySession` authority class.
@MainActor
struct AllAboardTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    private func startParty(modeSlug: String, deck: [TriviaQuestion], minPlayers: Int = 2) {
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.curveballPreviewDuration = .zero
        session.wagerDuration = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: modeSlug, modeName: modeSlug,
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: minPlayers)
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

    /// Plays questions `0..<count` normally (everyone answers, nothing
    /// eliminated) so a test can fast-forward to a specific All Aboard
    /// question — none of these indices are multiples of 5.
    private func playNormalQuestions(deck: [TriviaQuestion], count: Int) async throws {
        for index in 0..<count {
            let correct = try #require(deck[index].correctOptionID)
            answer(hostID, correct)
            answer(riderID, correct)
            answer(backseatID, correct)
            await session.debugWaitForAdvance()
        }
    }

    @Test func driverIsExcludedFromTheAnswerGateOnAnAllAboardQuestion() async throws {
        startParty(modeSlug: "three-strikes", deck: SeedQuestions.movieQuoteMashup, minPlayers: 3)
        session.assignRole(.pilot, to: hostID)
        try await playNormalQuestions(deck: SeedQuestions.movieQuoteMashup, count: 4)

        #expect(session.state?.round?.questionIndex == 4, "question 5 (index 4) is the first All Aboard question")
        let deck = try #require(session.state?.round?.questions)
        let correct = try #require(deck[4].correctOptionID)
        let wrong = try #require(deck[4].options.first { $0.id != correct })

        // The driver's tap is rejected outright — not scored, not counted.
        answer(hostID, correct)
        #expect(session.state?.round?.revealing != true)
        #expect(session.state?.player(hostID)?.lastAnswerCorrect == nil)

        // Rider is correct, backseat is wrong — not unanimous, so no group
        // bonus even though the question still resolves normally.
        answer(riderID, correct)
        answer(backseatID, wrong.id)
        #expect(session.state?.round?.revealing == true)
        #expect(session.state?.player(riderID)?.score == 4 + 1)
        #expect(session.state?.player(backseatID)?.score == 4)
        #expect(session.state?.player(backseatID)?.strikes == 1)
        #expect(session.state?.player(hostID)?.score == 4, "the driver's rejected tap never touched their score")
    }

    @Test func groupBonusAppliesWhenEveryParticipatingNonDriverIsCorrect() async throws {
        startParty(modeSlug: "three-strikes", deck: SeedQuestions.movieQuoteMashup, minPlayers: 3)
        session.assignRole(.pilot, to: hostID)
        try await playNormalQuestions(deck: SeedQuestions.movieQuoteMashup, count: 4)

        let deck = try #require(session.state?.round?.questions)
        let correct = try #require(deck[4].correctOptionID)
        answer(riderID, correct)
        answer(backseatID, correct)
        await session.debugWaitForAdvance()

        #expect(session.state?.player(riderID)?.score == 4 + 1 + AllAboard.groupBonus)
        #expect(session.state?.player(backseatID)?.score == 4 + 1 + AllAboard.groupBonus)
        #expect(session.state?.player(hostID)?.score == 4, "the driver never participated, bonus or not")
    }

    @Test func eliminationBracketExcludesAlreadyEliminatedPlayersFromAllAboard() async throws {
        startParty(modeSlug: Elimination.bracketModeSlug, deck: SeedQuestions.movieQuoteMashup, minPlayers: 3)
        let deck = try #require(session.state?.round?.questions)

        // Rider misses immediately — one strike is enough to be out.
        let q0Correct = try #require(deck[0].correctOptionID)
        let q0Wrong = try #require(deck[0].options.first { $0.id != q0Correct })
        answer(hostID, q0Correct)
        answer(riderID, q0Wrong.id)
        answer(backseatID, q0Correct)
        await session.debugWaitForAdvance()
        #expect(session.state?.player(riderID)?.strikes == 1)

        try await playFrom(deck: deck, start: 1, upTo: 4)
        #expect(session.state?.round?.questionIndex == 4)

        // Rider is out — their All Aboard tap is rejected too, same as any
        // other question. Not a "for fun" participation tier.
        let correct = try #require(deck[4].correctOptionID)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
        #expect(session.state?.round?.revealing != true)
        #expect(session.state?.player(riderID)?.lastAnswerCorrect == nil)

        answer(hostID, correct)
        answer(backseatID, correct)
        #expect(session.state?.round?.revealing == true)
        // Only the two still-in-it players counted toward the group bonus:
        // 1 point each from question 0, 3 more from questions 1-3, +1 for
        // this one, plus the whole-car bonus (the eliminated rider was
        // never a participant to break the "everyone" in "everyone correct").
        #expect(session.state?.player(hostID)?.score == 4 + 1 + AllAboard.groupBonus)
        #expect(session.state?.player(backseatID)?.score == 4 + 1 + AllAboard.groupBonus)
    }

    private func playFrom(deck: [TriviaQuestion], start: Int, upTo: Int) async throws {
        for index in start..<upTo {
            let correct = try #require(deck[index].correctOptionID)
            answer(hostID, correct)
            answer(backseatID, correct)
            await session.debugWaitForAdvance()
        }
    }

    @Test func teamRelayAllAboardLetsBothSquadsAnswerThenResumesNormalRotation() async throws {
        let deck = SeedQuestions.movieQuoteMashup
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let fourthID = UUID()
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

        #expect(session.state?.round?.teamTurnPlayerID == [hostID, backseatID])

        // Play questions 0-3 normally, turn-based — rider and fourth each
        // get exactly 2 of those 4 turns (seat-order rotation).
        for _ in 0..<4 {
            let index = try #require(session.state?.round?.questionIndex)
            let correct = try #require(deck[index].correctOptionID)
            let turn = try #require(session.state?.round?.teamTurnPlayerID).compactMap { $0 }
            for id in turn {
                session.debugApplyIntent(.submitAnswer(playerID: id, optionID: correct))
            }
            await session.debugWaitForAdvance()
        }
        #expect(session.state?.round?.questionIndex == 4)
        let riderScoreBeforeAllAboard = try #require(session.state?.player(riderID)?.score)
        #expect(riderScoreBeforeAllAboard == 2)

        // All Aboard: everyone on both squads answers this one, not just
        // whoever's turn it is (host/backseat, per the rotation above).
        let correct = try #require(deck[4].correctOptionID)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))    // off-turn, team 0
        session.debugApplyIntent(.submitAnswer(playerID: fourthID, optionID: correct))   // off-turn, team 1
        #expect(session.state?.round?.revealing != true, "still waiting on the on-turn players too")
        session.debugApplyIntent(.submitAnswer(playerID: hostID, optionID: correct))
        session.debugApplyIntent(.submitAnswer(playerID: backseatID, optionID: correct))
        #expect(session.state?.round?.revealing == true)
        #expect(session.state?.player(riderID)?.score == riderScoreBeforeAllAboard + 1 + AllAboard.groupBonus)

        await session.debugWaitForAdvance()
        // Rotation resumes exactly where it left off — All Aboard never
        // touched `teamTurnPlayerID`, since nobody's individual turn was
        // "used" by a question everybody answered.
        #expect(session.state?.round?.teamTurnPlayerID == [riderID, fourthID])
    }

}

/// The cadence math itself, including the Double or Nothing exemption when
/// All Aboard's every-5th and the wager round's every-4th coincide (every
/// 20th question) — stacking a flat group bonus onto a +wager/-wager
/// settlement would collide both mechanically and visually, so the wager
/// question wins and All Aboard sits that one out.
struct AllAboardCadenceTests {
    @Test func exemptsDoubleOrNothingWagerQuestionsWhenCadencesCoincide() {
        #expect(AllAboard.isAllAboardIndex(19) == true)
        #expect(DoubleOrNothing.isWagerIndex(19) == true)
        #expect(AllAboard.isActive(19, modeSlug: DoubleOrNothing.modeSlug) == false)
        // Same index, any other mode: unaffected, still All Aboard.
        #expect(AllAboard.isActive(19, modeSlug: "three-strikes") == true)
        // A non-coinciding All Aboard index still fires normally even in
        // Double or Nothing.
        #expect(AllAboard.isActive(4, modeSlug: DoubleOrNothing.modeSlug) == true)
        #expect(AllAboard.isActive(3, modeSlug: "three-strikes") == false)
    }

    /// Would You Rather already has every non-driver seat voting on every
    /// question by design — All Aboard's cadence never fires for it, on any
    /// index, not even the ones that would normally trigger it.
    @Test func excludesWouldYouRatherEntirely() {
        #expect(AllAboard.isActive(4, modeSlug: WouldYouRatherMode.modeSlug) == false)
        #expect(AllAboard.isActive(9, modeSlug: WouldYouRatherMode.modeSlug) == false)
        #expect(AllAboard.isAllAboardIndex(4) == true, "index 4 would fire for any other mode")
    }
}

/// Copilot's Curveball × All Aboard, when the every-4th preview and the
/// every-5th bonus question land on the same question (every 20th): the
/// preview mechanic is untouched (still only the copilot peeks, still
/// nobody can answer during the window), and once it opens, it opens as an
/// All Aboard question — the driver still can't answer even though nothing
/// stops them on every other question in this mode.
@MainActor
struct AllAboardCurveballTests {
    let session = PartySession()
    let hostID = UUID()
    let riderID = UUID()
    let backseatID = UUID()

    @Test func driverStillExcludedOnceTheCoincidingCurveballPreviewOpens() async throws {
        let deck = SeedQuestions.movieQuoteMashup
        session.suppressesNetworking = true
        session.revealDuration = .zero
        session.nobodyConnectedDelay = .zero
        // Deliberately non-zero: a zero-duration preview window races
        // against the many chained `debugWaitForAdvance()` calls this test
        // needs to reach the 20th question, since the preview-ending Task
        // can slip in during one of those awaits. A short real duration
        // keeps "still in preview until I explicitly wait it out"
        // deterministic instead.
        session.curveballPreviewDuration = .milliseconds(30)
        session.dealDeck = { _ in (deck, "movie-quote-mashup", "movie-quote-mashup") }
        let config = PartyConfig(modeSlug: CopilotsCurveball.modeSlug, modeName: "Copilot's Curveball",
                                 genreSlug: "movie-quote-mashup", genreName: "movie-quote-mashup",
                                 difficulty: .familyMix, minPlayers: 3)
        session.host(partyName: "Testers", code: "1234", config: config,
                     playerID: hostID, playerName: "Pilot")
        session.debugApplyIntent(.hello(playerID: riderID, name: "Rider"))
        session.debugApplyIntent(.hello(playerID: backseatID, name: "Backseat"))
        session.assignRole(.pilot, to: hostID)
        session.assignRole(.copilot, to: riderID)
        session.startRide()
        session.startTrip()

        // Fast-forward through questions 0-18 — the driver answers normally
        // throughout, since nothing restricts a non-All-Aboard question.
        for index in 0..<19 {
            if CopilotsCurveball.isCurveballIndex(index) {
                await session.debugWaitForCurveballWindow()
            }
            let correct = try #require(session.state?.round?.questions[index].correctOptionID)
            session.submitLocalAnswer(optionID: correct)
            session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
            session.debugApplyIntent(.submitAnswer(playerID: backseatID, optionID: correct))
            await session.debugWaitForAdvance()
        }
        #expect(session.state?.round?.questionIndex == 19)
        #expect(session.state?.round?.curveballPreview == true,
                "the 20th question still opens with its curveball preview, untouched by All Aboard")

        // Nobody can answer during the preview — that mechanic is untouched.
        let correct = try #require(session.state?.round?.questions[19].correctOptionID)
        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
        #expect(session.state?.round?.revealing != true)

        await session.debugWaitForCurveballWindow()
        #expect(session.state?.round?.curveballPreview == false)

        // Once it opens, it's an All Aboard question: the driver (host) is
        // excluded even though nothing stopped them on the other 19.
        session.submitLocalAnswer(optionID: correct)
        #expect(session.state?.round?.revealing != true, "the driver's tap on an All Aboard question is rejected")

        session.debugApplyIntent(.submitAnswer(playerID: riderID, optionID: correct))
        session.debugApplyIntent(.submitAnswer(playerID: backseatID, optionID: correct))
        #expect(session.state?.round?.revealing == true)
        // 19 base points from questions 0-18, plus the group bonus already
        // earned on the 3 earlier All Aboard questions in that span
        // (indices 4, 9, 14), plus this one: +1 base and another bonus.
        let earlierAllAboardHits = 3
        let expectedScore = 19 + earlierAllAboardHits * AllAboard.groupBonus + 1 + AllAboard.groupBonus
        #expect(session.state?.player(riderID)?.score == expectedScore)
    }
}
