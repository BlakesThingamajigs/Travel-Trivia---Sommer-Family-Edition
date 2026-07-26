//
//  RoadSignButton.swift
//  Travel Trivia
//
//  Primary CTA styled as a highway sign: colored panel, white inner border,
//  ink sticker outline. Use inside a Button with `.bubble` style.
//

import SwiftUI

struct RoadSignLabel: View {
    var title: String
    var color: Color = TT.signGreen
    var textSize: CGFloat = 21

    var body: some View {
        Text(title.uppercased())
            .font(TT.font(textSize, .black))
            .tracking(1.5)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(TT.ink).offset(y: 6)
                    RoundedRectangle(cornerRadius: 15).fill(color)
                    RoundedRectangle(cornerRadius: 15).strokeBorder(TT.ink, lineWidth: 3.5)
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white, lineWidth: 2.5)
                        .padding(7)
                }
            }
    }
}

/// Little green "MILE X" marker sign.
struct MileMarker: View {
    var current: Int
    var total: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("MILE")
                .font(TT.font(10, .black))
            Text("\(current)/\(total)")
                .font(TT.font(16, .black))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .sticker(RoundedRectangle(cornerRadius: 8), fill: TT.signGreen,
                 lineWidth: 2.5, drop: CGSize(width: 0, height: 4))
    }
}
