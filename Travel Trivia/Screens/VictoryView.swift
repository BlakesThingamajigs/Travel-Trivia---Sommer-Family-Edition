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
}
