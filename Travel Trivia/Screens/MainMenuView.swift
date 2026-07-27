//
//  MainMenuView.swift
//  Travel Trivia
//
//  The front door: big sticker logo, two primary road-sign CTAs, and a
//  small corner gear for Settings (deliberately not equal weight).
//

import SwiftUI

struct MainMenuView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BubbleIconButton(systemName: "car.2.fill", fill: TT.paper) {
                    app.route = .garage
                }
                .accessibilityIdentifier("menu-garage")
                Spacer()
                BubbleIconButton(systemName: "gearshape.fill", fill: TT.paper) {
                    app.route = .settings
                }
                .accessibilityIdentifier("menu-settings")
            }
            .padding(.horizontal, 20)

            Spacer()

            logo

            if let message = app.partyClosedMessage {
                StickerChip(text: message.uppercased(), fill: TT.cherry,
                            textColor: .white, textSize: 12)
                    .padding(.top, 18)
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            VStack(spacing: 18) {
                Button {
                    app.partyClosedMessage = nil
                    app.route = .createGame
                } label: {
                    RoadSignLabel(title: "Create a New Game", color: TT.signGreen, textSize: 19)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("menu-create")

                Button {
                    app.partyClosedMessage = nil
                    app.route = .joinGame
                } label: {
                    RoadSignLabel(title: "Join a Game", color: TT.tangerine, textSize: 19)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("menu-join")
            }

            Spacer()
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var logo: some View {
        VStack(spacing: 2) {
            StickerText(text: "TRAVEL", size: 56, fill: TT.sunshine)
                .rotationEffect(.degrees(-3))
            StickerText(text: "TRIVIA", size: 62, fill: .white)
                .rotationEffect(.degrees(2))
            StickerChip(text: "SOMMER FAMILY EDITION", fill: TT.grape,
                        textColor: .white, textSize: 11)
                .rotationEffect(.degrees(-2))
                .padding(.top, 10)
        }
    }
}
