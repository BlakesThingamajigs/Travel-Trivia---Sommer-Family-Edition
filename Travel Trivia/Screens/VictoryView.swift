//
//  VictoryView.swift
//  Travel Trivia
//
//  End-of-round celebration: winner's full-body avatar bouncing under
//  repeating confetti. The full Rive victory dance replaces the bounce
//  later; the layout already leaves the avatar center stage for it.
//

import SwiftUI

struct VictoryView: View {
    @Environment(GameEngine.self) private var engine
    @State private var confettiTick = 0
    @State private var bouncing = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            StickerText(text: "WINNER!", size: 52)
                .accessibilityIdentifier("victory-title")

            if let winner = engine.winner {
                AvatarFullBody(color: TT.avatarColors[winner.colorIndex % TT.avatarColors.count],
                               expression: .happy,
                               height: 210)
                    .offset(y: bouncing ? -22 : 6)
                    .rotationEffect(.degrees(bouncing ? 3 : -3))

                StickerChip(text: winner.isUser ? "\(winner.name) (You)" : winner.name,
                            fill: TT.sunshine, textSize: 18)
                LicensePlate(name: "Champion", score: winner.score)
                StickerChip(text: "CHAMPION OF THE RIDE", fill: TT.grape,
                            textColor: .white, textSize: 12)
            }

            Spacer()

            Button {
                engine.backToRide()
            } label: {
                RoadSignLabel(title: "Back to the Ride", color: TT.skyDeep)
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("back-to-ride")
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .overlay {
            ConfettiBurst(trigger: confettiTick, origin: .init(x: 0.5, y: 0.25), pieceCount: 36)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.32).repeatForever(autoreverses: true)) {
                bouncing = true
            }
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
