//
//  PlaceholderAvatar.swift
//  Travel Trivia
//
//  Stand-in avatar art until real Wii/Mii-style characters exist as Rive
//  files. These views are the single swap point: when the Rive pipeline
//  lands, AvatarHead and AvatarFullBody get reimplemented around RiveView
//  with the same API (color slot + expression), and no screen changes.
//

import SwiftUI

enum AvatarExpression {
    case idle, happy, sad, wow
}

struct AvatarHead: View {
    var color: Color
    var expression: AvatarExpression = .idle
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            // Sticker ring: white halo behind the head
            Circle()
                .fill(TT.ink)
                .frame(width: size + 8, height: size + 8)
                .offset(y: 3)
            Circle()
                .fill(.white)
                .frame(width: size + 8, height: size + 8)
            Circle()
                .fill(color)
                .overlay(Circle().stroke(TT.ink, lineWidth: size * 0.06))
                .frame(width: size, height: size)
            face
        }
    }

    private var face: some View {
        VStack(spacing: size * 0.08) {
            HStack(spacing: size * 0.22) {
                eye
                eye
            }
            mouth
        }
        .offset(y: size * 0.05)
    }

    private var eye: some View {
        Circle()
            .fill(TT.ink)
            .frame(width: eyeSize, height: eyeSize)
            .scaleEffect(y: expression == .sad ? 0.55 : 1)
    }

    private var eyeSize: CGFloat {
        expression == .wow ? size * 0.16 : size * 0.12
    }

    @ViewBuilder
    private var mouth: some View {
        switch expression {
        case .happy:
            Circle()
                .trim(from: 0.08, to: 0.42)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.4, height: size * 0.4)
                .frame(height: size * 0.18, alignment: .top)
        case .sad:
            Circle()
                .trim(from: 0.58, to: 0.92)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.36, height: size * 0.36)
                .frame(height: size * 0.18, alignment: .bottom)
        case .wow:
            Circle()
                .fill(TT.ink)
                .frame(width: size * 0.16, height: size * 0.16)
        case .idle:
            Capsule()
                .fill(TT.ink)
                .frame(width: size * 0.26, height: size * 0.055)
        }
    }
}

struct AvatarFullBody: View {
    var color: Color
    var expression: AvatarExpression = .idle
    var height: CGFloat = 130

    var body: some View {
        VStack(spacing: -height * 0.10) {
            AvatarHead(color: color, expression: expression, size: height * 0.42)
                .zIndex(1)
            // Body: rounded capsule torso in a darker take of the same hue
            Capsule()
                .fill(color)
                .overlay(
                    Capsule()
                        .fill(TT.ink.opacity(0.18))
                        .padding(.top, height * 0.28)
                )
                .overlay(Capsule().stroke(TT.ink, lineWidth: height * 0.025))
                .frame(width: height * 0.42, height: height * 0.52)
        }
        .frame(height: height)
    }
}

/// One-shot squash-and-stretch reaction bounce, driven by a trigger change.
private struct AvatarReactionModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content
            .phaseAnimator([1.0, 1.22, 1.0], trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } animation: { _ in
                .spring(response: 0.28, dampingFraction: 0.45)
            }
    }
}

extension View {
    /// Makes an avatar (or anything) do a happy bounce when `trigger` changes.
    func reactionBounce(trigger: Int) -> some View {
        modifier(AvatarReactionModifier(trigger: trigger))
    }
}
