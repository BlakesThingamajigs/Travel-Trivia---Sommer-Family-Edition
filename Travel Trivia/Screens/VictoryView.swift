//
//  VictoryView.swift
//  Travel Trivia
//
//  End-of-round celebration: winner's full-body avatar doing a looping
//  victory dance under repeating confetti. A real Rive victory dance
//  replaces this later; the layout already leaves the avatar center stage
//  for it.
//

import SwiftUI

struct VictoryView: View {
    @Environment(GameEngine.self) private var engine
    @Environment(AppModel.self) private var app
    @State private var confettiTick = 0
    @State private var showRoundPicker = false

    var body: some View {
        if showRoundPicker, let config = app.party.state?.config {
            PlayAnotherRoundPicker(currentConfig: config, onStart: { newConfig in
                engine.playAnotherRound(config: newConfig)
                showRoundPicker = false
            }, onCancel: {
                showRoundPicker = false
            })
        } else {
            celebration
        }
    }

    private var celebration: some View {
        VStack(spacing: 16) {
            Spacer()

            if engine.isWouldYouRatherMode {
                WouldYouRatherRecap(highlights: recapHighlights)
            } else {
                StickerText(text: "WINNER!", size: 52)
                    .accessibilityIdentifier("victory-title")

                if let winner = engine.winner {
                    AvatarFullBody(color: TT.avatarColors[winner.colorIndex % TT.avatarColors.count],
                                   expression: .happy,
                                   height: 210,
                                   hatID: winner.isUser ? app.progress.avatarLoadout.hatID : "hat-none",
                                   accessoryID: winner.isUser ? app.progress.avatarLoadout.accessoryID : "acc-none",
                                   stickerID: winner.isUser ? app.progress.avatarLoadout.stickerID : "sticker-none",
                                   hairID: winner.isUser ? app.progress.avatarLoadout.hairID : "hair-none",
                                   faceMarkID: winner.isUser ? app.progress.avatarLoadout.faceMarkID : "face-none",
                                   headShapeID: winner.isUser ? app.progress.avatarLoadout.headShapeID : "shape-round")
                        .victoryDance()

                    StickerChip(text: winner.isUser ? "\(winner.name) (You)" : winner.name,
                                fill: TT.sunshine, textSize: 18)
                    LicensePlate(name: "Champion", score: winner.score)
                    StickerChip(text: "CHAMPION OF THE RIDE", fill: TT.grape,
                                textColor: .white, textSize: 12)
                }
            }

            Spacer()

            if engine.playContext == .practice {
                Button {
                    engine.backToRide()
                } label: {
                    RoadSignLabel(title: "Back to the Ride", color: TT.skyDeep)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("back-to-ride")
                .padding(.bottom, 20)
            } else if engine.playContext == .partyHost {
                VStack(spacing: 10) {
                    Button {
                        showRoundPicker = true
                    } label: {
                        RoadSignLabel(title: "Play Another Round", color: TT.skyDeep)
                    }
                    .buttonStyle(.bubble)
                    .accessibilityIdentifier("play-another-round")

                    Button {
                        app.leaveParty()
                    } label: {
                        StickerChip(text: "END THE PARTY", fill: TT.cherry,
                                    textColor: .white, textSize: 12)
                    }
                    .buttonStyle(.bubble)
                    .accessibilityIdentifier("end-the-party")
                }
                .padding(.bottom, 20)
            } else {
                StickerChip(text: "THE HOST PICKS THE NEXT STOP…",
                            fill: TT.sunshine, textSize: 12)
                    .padding(.bottom, 26)
            }
        }
        .padding(.horizontal, 24)
        .overlay {
            ConfettiBurst(trigger: confettiTick, origin: .init(x: 0.5, y: 0.25), pieceCount: 36)
        }
        .task {
            // Keep the party going: a fresh burst every 1.2 s. The short
            // initial delay lets the confetti canvas mount before the first
            // trigger lands.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.25))
                confettiTick += 1
                try? await Task.sleep(for: .seconds(0.95))
            }
        }
    }

    /// Would You Rather's recap: "Most Split Vote" (the round's
    /// closest-to-even question) and "Most Agreed-Upon" (closest to
    /// unanimous), derived from `RoundState.voteHistory` — this mode
    /// declares no winner, so the recap replaces the leaderboard entirely.
    private var recapHighlights: [RecapHighlight] {
        guard let round = app.party.state?.round else { return [] }
        let shares: [(question: TriviaQuestion, share: Double)] = zip(round.questions, round.voteHistory)
            .compactMap { question, counts in
                let total = counts.values.reduce(0, +)
                guard total > 0, let top = counts.values.max() else { return nil }
                return (question, Double(top) / Double(total))
            }
        guard !shares.isEmpty else { return [] }
        var highlights: [RecapHighlight] = []
        if let mostSplit = shares.min(by: { $0.share < $1.share }) {
            highlights.append(RecapHighlight(title: "MOST SPLIT VOTE",
                                             subtitle: "The car couldn't agree on this one",
                                             prompt: mostSplit.question.prompt))
        }
        if let mostAgreed = shares.max(by: { $0.share < $1.share }) {
            highlights.append(RecapHighlight(title: "MOST AGREED-UPON",
                                             subtitle: "Everybody was thinking the same thing",
                                             prompt: mostAgreed.question.prompt))
        }
        return highlights
    }
}

/// A single Would You Rather recap card's content.
private struct RecapHighlight: Identifiable {
    var title: String
    var subtitle: String
    var prompt: String
    var id: String { title }
}

/// Would You Rather's end-of-round screen: this mode is purely social (no
/// scoring, no winner — see WouldYouRatherMode), so instead of a leaderboard
/// it recaps a couple of fun highlights from the round's votes.
private struct WouldYouRatherRecap: View {
    var highlights: [RecapHighlight]

    var body: some View {
        VStack(spacing: 18) {
            StickerText(text: "ROAD TRIP RECAP", size: 34)
                .accessibilityIdentifier("wyr-recap-title")
            StickerChip(text: "WOULD YOU RATHER — NO WINNER, JUST FUN",
                        fill: TT.grape, textColor: .white, textSize: 12)

            if highlights.isEmpty {
                Text("Not enough votes in to call a highlight this round!")
                    .font(TT.font(14, .bold))
                    .foregroundStyle(TT.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(highlights) { highlight in
                        VStack(spacing: 6) {
                            StickerChip(text: highlight.title, fill: TT.sunshine, textSize: 13)
                            Text(highlight.subtitle)
                                .font(TT.font(11, .bold))
                                .foregroundStyle(TT.ink.opacity(0.7))
                            Text("\u{201C}\(highlight.prompt)\u{201D}")
                                .font(TT.font(15, .heavy))
                                .foregroundStyle(TT.ink)
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .sticker(RoundedRectangle(cornerRadius: 18), fill: TT.paper)
                        .accessibilityIdentifier("wyr-recap-\(highlight.title.lowercased().replacingOccurrences(of: " ", with: "-"))")
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}
