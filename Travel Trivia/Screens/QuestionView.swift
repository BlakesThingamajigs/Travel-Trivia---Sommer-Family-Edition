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
    @State private var scoreboardOpen = false

    private var userIsOut: Bool {
        engine.userPlayer?.isOut ?? true
    }

    var body: some View {
        VStack(spacing: 10) {
            header

            if let question = engine.currentQuestion {
                RiddleCard(question: question)

                AvatarStrip()

                if userIsOut {
                    StickerChip(text: "YOU'RE OUT — ENJOY THE RIDE!",
                                fill: TT.cherry, textColor: .white, textSize: 13)
                        .transition(.scale.combined(with: .opacity))
                }

                AnswerGrid(question: question)
            }

            Spacer(minLength: 0)
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
                StickerChip(text: "RIDDLE REALM", fill: TT.grape, textColor: .white, textSize: 11)
                StickerChip(text: question.difficulty.displayName,
                            fill: difficultyColor, textColor: .white, textSize: 11)
                Spacer()
            }
            Text(question.prompt)
                .font(TT.font(19, .bold))
                .foregroundStyle(TT.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
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
                       size: 46)
                .reactionBounce(trigger: player.lastAnswerCorrect == true ? engine.reactionTrigger : 0)
                .shake(trigger: player.lastAnswerCorrect == false ? engine.reactionTrigger : 0)
                .overlay(alignment: .topTrailing) {
                    if player.isOut {
                        StickerChip(text: "OUT", fill: TT.cherry, textColor: .white, textSize: 8)
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
        .frame(width: 64)
        .opacity(player.isOut ? 0.55 : 1)
        .saturation(player.isOut ? 0.25 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: player.isOut)
    }
}

struct StrikePips: View {
    var player: Player

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<GameEngine.maxStrikes, id: \.self) { i in
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
    private var isCorrectOption: Bool { option.id == question.correctOptionID }
    private var isUsersWrongPick: Bool {
        isRevealing && engine.userPickedOptionID == option.id && !isCorrectOption
    }
    private var buttonColor: Color { TT.answerColors[index % TT.answerColors.count] }
    private var userCanAnswer: Bool {
        engine.turnState == .awaitingAnswer && !(engine.userPlayer?.isOut ?? true)
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
                .frame(maxWidth: .infinity, minHeight: 62)
                .sticker(RoundedRectangle(cornerRadius: 18), fill: buttonColor)
                .overlay {
                    if isRevealing && isCorrectOption {
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
