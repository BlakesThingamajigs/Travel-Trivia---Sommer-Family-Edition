//
//  GasGauge.swift
//  Travel Trivia
//
//  Round-progress indicator themed as a fuel gauge: the tank starts full
//  and burns down as the round's questions are used up.
//

import SwiftUI

struct GasGauge: View {
    /// 1 = full tank (round start), 0 = empty (round over).
    var fuel: Double

    private var needleAngle: Angle {
        // E on the left (-72°), F on the right (+72°)
        .degrees(-72 + max(0, min(1, fuel)) * 144)
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack(alignment: .bottom) {
                dial
                needle
            }
            .frame(width: 62, height: 34)
            Text("FUEL")
                .font(TT.font(9, .black))
                .foregroundStyle(TT.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .sticker(RoundedRectangle(cornerRadius: 11), fill: TT.paper,
                 lineWidth: 2.5, drop: CGSize(width: 0, height: 4))
    }

    private var dial: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .trim(from: 0.5, to: 1)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 54, height: 54)
            // Low-fuel warning zone on the E side
            Circle()
                .trim(from: 0.5, to: 0.62)
                .stroke(TT.cherry, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 54, height: 54)
            HStack {
                Text("E").padding(.leading, 1)
                Spacer()
                Text("F").padding(.trailing, 1)
            }
            .font(TT.font(9, .black))
            .foregroundStyle(TT.ink)
            .frame(width: 62)
            .offset(y: -1)
        }
        .frame(height: 30, alignment: .top)
        .clipped()
    }

    private var needle: some View {
        Capsule()
            .fill(TT.cherry)
            .overlay(Capsule().stroke(TT.ink, lineWidth: 1))
            .frame(width: 4, height: 24)
            .offset(y: -10)
            .rotationEffect(needleAngle, anchor: .bottom)
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(TT.ink)
                    .frame(width: 8, height: 8)
                    .offset(y: 3)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: fuel)
    }
}
