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

    private var standings: [Player] {
        engine.players.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.strikes < $1.strikes
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            StickerChip(text: "STANDINGS", fill: TT.grape, textColor: .white, textSize: 12)
            ForEach(standings, id: \.persistentModelID) { player in
                ScoreboardRow(player: player)
            }
        }
        .padding(14)
        .sticker(RoundedRectangle(cornerRadius: 22), fill: TT.paper, drop: CGSize(width: 0, height: 6))
        .accessibilityIdentifier("scoreboard-panel")
    }
}

private struct ScoreboardRow: View {
    var player: Player

    var body: some View {
        HStack(spacing: 10) {
            AvatarHead(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                       expression: player.isOut ? .sad : .idle,
                       size: 34)
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
