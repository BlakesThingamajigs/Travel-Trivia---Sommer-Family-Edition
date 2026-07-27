//
//  QuestionView.swift
//  Travel Trivia
//
//  Three Strikes × Riddle Realm: narrated riddle card, 2×3 answer grid of
//  bubble buttons, avatar reactions, confetti on correct, screen shake on
//  wrong, scoreboard behind a chevron dropdown.
//

import SwiftUI
import SwiftData

struct QuestionView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(AppModel.self) private var app
    @State private var scoreboardOpen = false

    /// One phone per party narrates out loud — the copilot's, per the
    /// party/multiplayer design (driver stays hands-free); practice mode
    /// has no assigned roles, so it always narrates for itself.
    private var narratesLocally: Bool {
        engine.playContext == .practice || engine.localPlayerIsCopilot
    }

    private func presentQuestionIfNeeded() {
        guard narratesLocally, !questionHiddenByCurveball, !wagerChoicePending,
              engine.turnState == .awaitingAnswer,
              let question = engine.currentQuestion else { return }
        app.audio.presentQuestion(question, genreSlug: engine.activeGenreSlug)
    }

    private var userIsOut: Bool {
        engine.userPlayer?.isOut ?? true
    }

    /// Party mode: answered, waiting on the rest of the car to resolve.
    private var lockedIn: Bool {
        engine.playContext != .practice
            && engine.turnState == .awaitingAnswer
            && engine.userPickedOptionID != nil
    }

    /// Curveball preview: the copilot gets the early peek; everyone else
    /// sees a cover card until the window ends.
    private var questionHiddenByCurveball: Bool {
        engine.curveballPreviewActive && !engine.localPlayerIsCopilot
    }

    /// Double or Nothing: the wager round's lock-in window is open and the
    /// local player (still in it) hasn't chosen yet — the question stays
    /// covered until they wager, same shape as the curveball cover.
    private var wagerChoicePending: Bool {
        engine.wagerWindowActive && engine.userSubmittedWager == nil
            && !(engine.userPlayer?.isOut ?? true)
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            if questionHiddenByCurveball {
                CurveballCover()
                Spacer(minLength: 8)
                AvatarStrip()
                Spacer(minLength: 8)
            } else if wagerChoicePending {
                WagerPromptCard(score: engine.userPlayer?.score ?? 0) { amount in
                    engine.submitLocalWager(amount)
                }
                Spacer(minLength: 8)
                AvatarStrip()
                Spacer(minLength: 8)
            } else if let question = engine.currentQuestion {
                RiddleCard(question: question)

                if engine.curveballPreviewActive {
                    StickerChip(text: "CURVEBALL — ONLY YOU CAN SEE THIS!",
                                fill: TT.tangerine, textColor: .white, textSize: 12)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityIdentifier("curveball-peek")
                }

                Spacer(minLength: 8)
                    .frame(maxHeight: 34)

                AvatarStrip()

                if userIsOut {
                    StickerChip(text: "YOU'RE OUT — ENJOY THE RIDE!",
                                fill: TT.cherry, textColor: .white, textSize: 13)
                        .transition(.scale.combined(with: .opacity))
                } else if engine.wagerWindowActive {
                    StickerChip(text: "WAGER LOCKED IN — WAITING FOR THE CAR…",
                                fill: TT.grape, textColor: .white, textSize: 12)
                        .transition(.scale.combined(with: .opacity))
                } else if engine.isTeamRelayMode && !engine.isMyTurnInTeamRelay {
                    StickerChip(text: "TEAMMATE'S TURN…", fill: TT.paper, textSize: 12)
                        .transition(.scale.combined(with: .opacity))
                } else if lockedIn {
                    StickerChip(text: "LOCKED IN — WAITING FOR THE CAR…",
                                fill: TT.sunshine, textSize: 12)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityIdentifier("locked-in")
                }

                Spacer(minLength: 8)

                AnswerGrid(question: question)
                    .padding(.bottom, 16)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .shake(trigger: engine.shakeTrigger)
        .overlay {
            ConfettiBurst(trigger: engine.confettiTrigger, origin: .init(x: 0.5, y: 0.42))
        }
        .overlay(alignment: .top) {
            if scoreboardOpen {
                ScoreboardDropdown()
                    .padding(.horizontal, 16)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: scoreboardOpen)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: userIsOut)
        .onAppear { presentQuestionIfNeeded() }
        .onChange(of: engine.currentQuestion?.id) { _, _ in presentQuestionIfNeeded() }
        .onDisappear { app.audio.stopAll() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            GasGauge(fuel: engine.fuelRemaining)
            Spacer()
            MileMarker(current: engine.questionIndex + 1, total: engine.questions.count)
            Spacer()
            Button {
                scoreboardOpen.toggle()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(TT.ink)
                    .rotationEffect(.degrees(scoreboardOpen ? 180 : 0))
                    .frame(width: 40, height: 40)
                    .sticker(Circle(), fill: TT.sunshine, lineWidth: 3,
                             drop: CGSize(width: 0, height: 4))
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("scoreboard-toggle")
        }
        .padding(.top, 4)
    }
}

// MARK: - Riddle card

private struct RiddleCard: View {
    @Environment(GameEngine.self) private var engine
    @Environment(AppModel.self) private var app
    var question: TriviaQuestion

    private var difficultyColor: Color {
        switch question.difficulty {
        case .easy: TT.lime
        case .medium: TT.sunshine
        case .hard: TT.cherry
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StickerChip(text: engine.activeGenreName.uppercased(),
                            fill: TT.grape, textColor: .white, textSize: 11)
                StickerChip(text: question.difficulty.displayName,
                            fill: difficultyColor, textColor: .white, textSize: 11)
                if engine.currentQuestionIsCurveball {
                    StickerChip(text: "CURVEBALL!", fill: TT.tangerine,
                                textColor: .white, textSize: 11)
                        .rotationEffect(.degrees(-4))
                } else if question.isMajorityScored || engine.isHerdRevealMode {
                    StickerChip(text: "CAR VOTES", fill: TT.sky,
                                textColor: .white, textSize: 11)
                } else if engine.currentQuestionIsWager {
                    StickerChip(text: "DOUBLE OR NOTHING!", fill: TT.grape,
                                textColor: .white, textSize: 11)
                }
                Spacer()
            }
            Text(question.prompt)
                .font(TT.font(19, .bold))
                .foregroundStyle(TT.ink)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: question.hasAudioClip ? 56 : 92, alignment: .topLeading)
                .accessibilityIdentifier("riddle-prompt")
            if question.hasAudioClip {
                replayButton
            }
        }
        .padding(14)
        .sticker(RoundedRectangle(cornerRadius: 20), fill: TT.paper)
        .overlay(alignment: .bottomLeading) {
            // Speech-bubble tail pointing at the narrating copilot below
            BubbleTail()
                .fill(TT.paper)
                .stroke(TT.ink, lineWidth: 3)
                .frame(width: 26, height: 20)
                .offset(x: 40, y: 16)
        }
        .id(question.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)))
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: question.id)
    }

    /// Lets anyone re-trigger the clip (car noise/engine drowned it out the
    /// first time) — plays locally on whichever phone taps it, same clip.
    private var replayButton: some View {
        Button {
            guard let url = AudioClipLibrary.url(for: question, genreSlug: engine.activeGenreSlug) else { return }
            app.audio.playClip(url: url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: app.audio.isPlayingClip ? "speaker.wave.3.fill" : "arrow.clockwise")
                    .font(.system(size: 13, weight: .black))
                Text(app.audio.isPlayingClip ? "PLAYING…" : "REPLAY SOUND")
                    .font(TT.font(12, .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .sticker(RoundedRectangle(cornerRadius: 12), fill: TT.skyDeep)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("replay-audio-clip")
    }
}

/// What everyone but the copilot sees during a curveball preview: the
/// question is hidden while the copilot gets their real-world head start.
private struct CurveballCover: View {
    @State private var wobble = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "eye.fill")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(wobble ? 6 : -6))
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                           value: wobble)
            StickerText(text: "CURVEBALL!", size: 34)
            Text("The copilot sees this one first.\nListen carefully… or don't.")
                .font(TT.font(15, .bold))
                .foregroundStyle(TT.ink)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 180)
        .sticker(RoundedRectangle(cornerRadius: 20), fill: TT.tangerine)
        .accessibilityIdentifier("curveball-cover")
        .onAppear { wobble = true }
        .transition(.scale.combined(with: .opacity))
    }
}

nonisolated struct BubbleTail: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY),
                          control: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Double or Nothing's wager step: pick how much of the current score to
/// risk on the bonus question before it opens — mirrors CurveballCover's
/// shape (a full-bleed card standing in for the question) but with three
/// wager choices instead of a passive wait.
private struct WagerPromptCard: View {
    var score: Int
    var choose: (Int) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dice.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
            StickerText(text: "DOUBLE OR NOTHING!", size: 26)
            Text("Wager some of your \(score) points.\nRight doubles it back, wrong takes it away.")
                .font(TT.font(15, .bold))
                .foregroundStyle(TT.ink)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                wagerButton("BANK IT", amount: 0)
                wagerButton("HALF", amount: score / 2)
                wagerButton("ALL IN", amount: score)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 220)
        .sticker(RoundedRectangle(cornerRadius: 20), fill: TT.grape)
        .accessibilityIdentifier("wager-prompt")
        .transition(.scale.combined(with: .opacity))
    }

    private func wagerButton(_ label: String, amount: Int) -> some View {
        Button {
            choose(amount)
        } label: {
            VStack(spacing: 2) {
                Text(label).font(TT.font(13, .heavy))
                Text("\(amount)").font(TT.font(11, .bold))
            }
            .foregroundStyle(TT.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .sticker(RoundedRectangle(cornerRadius: 14), fill: TT.sunshine)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("wager-\(amount == 0 ? "bank" : (amount == score ? "all-in" : "half"))")
    }
}

// MARK: - Avatar strip

private struct AvatarStrip: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        HStack(spacing: 18) {
            ForEach(engine.players, id: \.persistentModelID) { player in
                PlayerBubble(player: player)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PlayerBubble: View {
    @Environment(GameEngine.self) private var engine
    @Environment(AppModel.self) private var app
    var player: Player

    private var expression: AvatarExpression {
        if player.isOut { return .sad }
        switch player.lastAnswerCorrect {
        case true?: return .happy
        case false?: return .sad
        case nil: return .idle
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            AvatarHead(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                       expression: expression,
                       size: 56,
                       hatID: player.isUser ? app.progress.avatarLoadout.hatID : "hat-none",
                       accessoryID: player.isUser ? app.progress.avatarLoadout.accessoryID : "acc-none",
                       stickerID: player.isUser ? app.progress.avatarLoadout.stickerID : "sticker-none")
                .reactionBounce(trigger: player.lastAnswerCorrect == true ? engine.reactionTrigger : 0)
                .shake(trigger: player.lastAnswerCorrect == false ? engine.reactionTrigger : 0)
                .overlay(alignment: .topTrailing) {
                    if player.isOut {
                        StickerChip(text: "OUT", fill: TT.cherry, textColor: .white, textSize: 8)
                            .rotationEffect(.degrees(12))
                            .offset(x: 10, y: -6)
                    } else if player.presence == .dropped {
                        StickerChip(text: "LOST", fill: TT.tangerine, textColor: .white, textSize: 8)
                            .rotationEffect(.degrees(12))
                            .offset(x: 10, y: -6)
                    } else if player.presence == .left {
                        StickerChip(text: "GONE", fill: TT.asphalt, textColor: .white, textSize: 8)
                            .rotationEffect(.degrees(12))
                            .offset(x: 10, y: -6)
                    }
                }
            Text(player.name)
                .font(TT.font(11, .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
            StrikePips(player: player)
        }
        .frame(width: 72)
        .opacity(player.isOut || player.presence != .connected ? 0.55 : 1)
        .saturation(player.isOut || player.presence != .connected ? 0.25 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: player.isOut)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: player.presence)
    }
}

struct StrikePips: View {
    var player: Player

    var body: some View {
        HStack(spacing: 3) {
            // Team Relay's threshold is effectively unlimited (strikes never
            // eliminate a relay player) — cap the pip row at the classic
            // three so it can't blow up into an unbounded ForEach.
            ForEach(0..<min(player.effectiveMaxStrikes, GameEngine.maxStrikes), id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(i < player.strikes ? TT.cherry : TT.paper)
                        .overlay(Circle().stroke(TT.ink, lineWidth: 1.6))
                        .frame(width: 11, height: 11)
                    if i < player.strikes {
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

// MARK: - Answer grid

private struct AnswerGrid: View {
    @Environment(GameEngine.self) private var engine
    var question: TriviaQuestion

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                AnswerButton(option: option, index: index, question: question)
            }
        }
        .padding(.top, 2)
    }
}

private struct AnswerButton: View {
    @Environment(GameEngine.self) private var engine
    var option: AnswerOption
    var index: Int
    var question: TriviaQuestion

    private var isRevealing: Bool { engine.turnState == .revealing }
    /// Authored answer, or the majority pick once a prediction question
    /// resolves — the engine owns which one applies.
    private var isCorrectOption: Bool {
        engine.revealedCorrectOptionID == option.id
    }
    private var isUsersWrongPick: Bool {
        isRevealing && engine.userPickedOptionID == option.id && !isCorrectOption
    }
    private var buttonColor: Color { TT.answerColors[index % TT.answerColors.count] }
    private var userCanAnswer: Bool {
        engine.turnState == .awaitingAnswer
            && !engine.curveballPreviewActive
            && !engine.wagerWindowActive
            && engine.isMyTurnInTeamRelay
            && engine.userPickedOptionID == nil
            && !(engine.userPlayer?.isOut ?? true)
    }
    /// Party mode: my pick, locked in while the rest of the car answers.
    private var isLockedInPick: Bool {
        engine.turnState == .awaitingAnswer && engine.userPickedOptionID == option.id
    }

    var body: some View {
        Button {
            engine.submitUserAnswer(optionID: option.id)
        } label: {
            Text(option.text)
                .font(TT.font(17, .heavy))
                .foregroundStyle(TT.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 82)
                .sticker(RoundedRectangle(cornerRadius: 18), fill: buttonColor)
                .overlay {
                    if (isRevealing && isCorrectOption) || isLockedInPick {
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(.white, lineWidth: 4)
                            .padding(2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isRevealing && isCorrectOption {
                        checkBadge
                    } else if isUsersWrongPick {
                        crossBadge
                    }
                }
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("answer-\(index)")
        .disabled(!userCanAnswer)
        .opacity(isRevealing && !isCorrectOption ? (isUsersWrongPick ? 0.9 : 0.45) : 1)
        .scaleEffect(isRevealing && isCorrectOption ? 1.06 : 1)
        .shake(trigger: isUsersWrongPick ? engine.shakeTrigger : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: isRevealing)
    }

    private var checkBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background { Circle().fill(TT.lime); Circle().stroke(TT.ink, lineWidth: 2.5) }
            .offset(x: 6, y: -8)
    }

    private var crossBadge: some View {
        Image(systemName: "xmark")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background { Circle().fill(TT.cherry); Circle().stroke(TT.ink, lineWidth: 2.5) }
            .offset(x: 6, y: -8)
    }
}
