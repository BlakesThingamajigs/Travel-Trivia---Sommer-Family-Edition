//
//  ScoreboardDropdown.swift
//  Travel Trivia
//
//  Standings panel that drops from the chevron on the question screen:
//  avatar head, name, strikes remaining, license-plate score per player.
//

import SwiftUI
import SwiftData

struct ScoreboardDropdown: View {
    @Environment(GameEngine.self) private var engine
    @Environment(AppModel.self) private var app
    @State private var confirmLeave = false

    private var standings: [Player] {
        engine.players.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.strikes < $1.strikes
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            StickerChip(text: "STANDINGS", fill: TT.grape, textColor: .white, textSize: 12)
            if engine.isTeamRelayMode {
                HStack(spacing: 8) {
                    StickerChip(text: "TEAM 1: \(engine.teamScore(0))", fill: TT.lime,
                                textColor: .white, textSize: 11)
                    StickerChip(text: "TEAM 2: \(engine.teamScore(1))", fill: TT.sky,
                                textColor: .white, textSize: 11)
                }
            }
            ForEach(standings, id: \.persistentModelID) { player in
                ScoreboardRow(player: player)
            }
            // Real party games only — practice has no roster to leave and
            // no networking to hand off.
            if engine.playContext != .practice {
                Button {
                    confirmLeave = true
                } label: {
                    StickerChip(text: "LEAVE GAME", fill: TT.cherry, textColor: .white, textSize: 11)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("leave-game")
            }
        }
        .padding(14)
        .sticker(RoundedRectangle(cornerRadius: 22), fill: TT.paper, drop: CGSize(width: 0, height: 6))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scoreboard-panel")
        .alert("Leave this game?", isPresented: $confirmLeave) {
            Button("Leave", role: .destructive) { app.leaveGameInProgress() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text(engine.playContext == .partyHost
                 ? "The rest of the car keeps playing — another rider takes over as host."
                 : "The rest of the car keeps playing without you.")
        }
    }
}

private struct ScoreboardRow: View {
    @Environment(AppModel.self) private var app
    var player: Player

    var body: some View {
        HStack(spacing: 10) {
            AvatarHead(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                       expression: player.isOut ? .sad : .idle,
                       size: 34,
                       hatID: player.isUser ? app.progress.avatarLoadout.hatID : "hat-none",
                       accessoryID: player.isUser ? app.progress.avatarLoadout.accessoryID : "acc-none",
                       stickerID: player.isUser ? app.progress.avatarLoadout.stickerID : "sticker-none",
                       hairID: player.isUser ? app.progress.avatarLoadout.hairID : "hair-none",
                       faceMarkID: player.isUser ? app.progress.avatarLoadout.faceMarkID : "face-none",
                       headShapeID: player.isUser ? app.progress.avatarLoadout.headShapeID : "shape-round")
            VStack(alignment: .leading, spacing: 2) {
                Text(player.isUser ? "\(player.name) (You)" : player.name)
                    .font(TT.font(14, .heavy))
                    .foregroundStyle(TT.ink)
                    .lineLimit(1)
                StrikePips(player: player)
            }
            Spacer()
            if player.isOut {
                StickerChip(text: "OUT", fill: TT.cherry, textColor: .white, textSize: 10)
                    .rotationEffect(.degrees(-6))
            }
            LicensePlate(name: player.name, score: player.score, compact: true)
        }
        .saturation(player.isOut ? 0.3 : 1)
        .opacity(player.isOut ? 0.75 : 1)
    }
}
