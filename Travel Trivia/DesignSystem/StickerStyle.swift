//
//  StickerStyle.swift
//  Travel Trivia
//
//  The core sticker treatment: a hard offset "shadow" in ink behind the
//  shape (never a blur), a flat fill, and a thick ink outline.
//

import SwiftUI

extension View {
    /// Wraps the view in a sticker-styled shape: offset ink slab behind,
    /// flat fill, thick outline.
    func sticker(
        _ shape: some InsettableShape,
        fill: Color,
        outline: Color = TT.ink,
        lineWidth: CGFloat = 3,
        drop: CGSize = CGSize(width: 0, height: 5)
    ) -> some View {
        background {
            ZStack {
                shape.fill(outline).offset(x: drop.width, y: drop.height)
                shape.fill(fill)
                shape.strokeBorder(outline, lineWidth: lineWidth)
            }
        }
    }
}

/// Big display text with a thick ink outline and hard drop, comic-logo style.
struct StickerText: View {
    var text: String
    var size: CGFloat
    var fill: Color = .white
    var outline: Color = TT.ink
    var outlineWidth: CGFloat = 3
    var drop: CGFloat = 5

    var body: some View {
        ZStack {
            // Hard offset drop layer
            layer(color: outline, dx: 0, dy: drop)
            // Fake outline: the text stamped in ink around the compass
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                layer(color: outline,
                      dx: cos(angle) * outlineWidth,
                      dy: sin(angle) * outlineWidth)
            }
            layer(color: fill, dx: 0, dy: 0)
        }
    }

    private func layer(color: Color, dx: CGFloat, dy: CGFloat) -> some View {
        Text(text)
            .font(TT.font(size, .black))
            .foregroundStyle(color)
            .offset(x: dx, y: dy)
    }
}

/// Small pill-shaped sticker chip, used for name tags and labels.
struct StickerChip: View {
    var text: String
    var fill: Color = TT.paper
    var textColor: Color = TT.ink
    var textSize: CGFloat = 12

    var body: some View {
        Text(text)
            .font(TT.font(textSize, .heavy))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .sticker(Capsule(), fill: fill, lineWidth: 2, drop: CGSize(width: 0, height: 3))
    }
}
