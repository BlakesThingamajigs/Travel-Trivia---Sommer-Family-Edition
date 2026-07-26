//
//  LicensePlate.swift
//  Travel Trivia
//
//  Score card themed as a license plate: state-name strip on top, big
//  stamped number, corner bolts.
//

import SwiftUI

struct LicensePlate: View {
    var name: String
    var score: Int
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 0 : 1) {
            Text(name.uppercased())
                .font(TT.font(compact ? 9 : 12, .black))
                .tracking(2)
                .foregroundStyle(TT.skyDeep)
                .lineLimit(1)
            Text(scoreText)
                .font(TT.font(compact ? 20 : 30, .black))
                .monospacedDigit()
                .foregroundStyle(TT.ink)
        }
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, compact ? 4 : 8)
        .frame(minWidth: compact ? 64 : 110)
        .sticker(RoundedRectangle(cornerRadius: compact ? 8 : 10), fill: TT.paper,
                 lineWidth: compact ? 2.5 : 3, drop: CGSize(width: 0, height: compact ? 3 : 5))
        .overlay(alignment: .top) {
            HStack {
                bolt
                Spacer()
                bolt
            }
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.top, compact ? 3 : 4)
        }
    }

    private var scoreText: String {
        String(format: "%02d", score) + " PTS"
    }

    private var bolt: some View {
        Circle()
            .fill(TT.asphalt)
            .overlay(Circle().stroke(TT.ink, lineWidth: 1.2))
            .frame(width: compact ? 4.5 : 6, height: compact ? 4.5 : 6)
    }
}
