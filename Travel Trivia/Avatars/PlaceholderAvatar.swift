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

    // Idle life: a slow breathing scale/bob and the occasional blink, kept
    // subtle enough that a whole row of avatars doesn't turn into a wall of
    // motion.
    @State private var breathing = false
    @State private var blinking = false

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
        .scaleEffect(breathing ? 1.018 : 1.0)
        .offset(y: breathing ? -size * 0.01 : size * 0.01)
        .task {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breathing = true
            }
            await runBlinkLoop()
        }
    }

    /// Waits a random, humanlike interval between blinks, then closes and
    /// reopens the eyes quickly. Skipped for `.happy`, whose eyes are
    /// already drawn as closed, contented crescents.
    private func runBlinkLoop() async {
        guard expression != .happy else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(.random(in: 2.4...5.2)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.07)) { blinking = true }
            try? await Task.sleep(for: .seconds(0.09))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.1)) { blinking = false }
        }
    }

    private var face: some View {
        ZStack {
            eyebrows
                .offset(y: -size * 0.30)
            HStack(spacing: size * 0.24) {
                eye
                eye.scaleEffect(x: -1) // mirror the highlight to the other side
            }
            .offset(y: -size * 0.09)
            if expression == .happy {
                HStack(spacing: size * 0.56) {
                    blush
                    blush
                }
                .offset(y: size * 0.10)
            }
            mouth
                .offset(y: size * 0.19)
        }
    }

    // MARK: Eyebrows

    private var eyebrows: some View {
        HStack(spacing: size * 0.16) {
            eyebrow.rotationEffect(.degrees(-browAngle))
            eyebrow.rotationEffect(.degrees(browAngle))
        }
        .offset(y: browLift)
    }

    private var eyebrow: some View {
        Capsule()
            .fill(TT.ink)
            .frame(width: size * 0.17, height: max(1.5, size * 0.035))
    }

    /// Positive tilts the outer end down (worried/neutral); negative tilts
    /// it up (cheerful/surprised).
    private var browAngle: Double {
        switch expression {
        case .idle: return 8
        case .happy: return -14
        case .sad: return 22
        case .wow: return -4
        }
    }

    private var browLift: CGFloat {
        switch expression {
        case .idle: return 0
        case .happy: return -size * 0.02
        case .sad: return size * 0.03
        case .wow: return -size * 0.05
        }
    }

    // MARK: Eyes

    @ViewBuilder
    private var eye: some View {
        if expression == .happy {
            // Contented closed-eye crescent, arcing upward.
            MouthShape(curve: -0.9)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.09)
        } else {
            ZStack {
                Circle()
                    .fill(TT.ink)
                    .frame(width: eyeSize, height: eyeSize)
                    .scaleEffect(y: (expression == .sad ? 0.55 : 1) * (blinking ? 0.08 : 1))
                Circle()
                    .fill(.white)
                    .frame(width: eyeSize * 0.34, height: eyeSize * 0.34)
                    .offset(x: -eyeSize * 0.2, y: -eyeSize * 0.2)
                    .opacity(blinking ? 0 : 1)
            }
        }
    }

    private var eyeSize: CGFloat {
        expression == .wow ? size * 0.17 : size * 0.125
    }

    // MARK: Blush (happy only)

    private var blush: some View {
        Ellipse()
            .fill(TT.bubblegum.opacity(0.55))
            .frame(width: size * 0.15, height: size * 0.09)
    }

    // MARK: Mouth

    @ViewBuilder
    private var mouth: some View {
        switch expression {
        case .happy:
            MouthShape(curve: 1.1)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round))
                .frame(width: size * 0.38, height: size * 0.17)
        case .sad:
            MouthShape(curve: -0.9)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.3, height: size * 0.12)
        case .wow:
            Ellipse()
                .fill(TT.ink)
                .frame(width: size * 0.17, height: size * 0.22)
        case .idle:
            MouthShape(curve: 0.35)
                .stroke(TT.ink, style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round))
                .frame(width: size * 0.26, height: size * 0.08)
        }
    }
}

/// Quad-curve mouth (or brow/eye arc): positive curve smiles, negative
/// frowns, 0 is flat.
nonisolated struct MouthShape: Shape {
    var curve: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = curve >= 0 ? rect.minY + rect.height * 0.15 : rect.maxY - rect.height * 0.15
        path.move(to: CGPoint(x: rect.minX, y: baseY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: baseY),
            control: CGPoint(x: rect.midX, y: baseY + curve * rect.height * 1.7)
        )
        return path
    }
}

struct AvatarFullBody: View {
    var color: Color
    var expression: AvatarExpression = .idle
    var height: CGFloat = 130

    var body: some View {
        VStack(spacing: -height * 0.05) {
            AvatarHead(color: color, expression: expression, size: height * 0.42)
                .zIndex(1)
            // Body: rounded capsule torso, wider than the head so the
            // silhouette reads as shoulders rather than a second, equally
            // sized blob stacked on the first (the "peanut head" look).
            Capsule()
                .fill(color)
                .overlay(
                    Capsule()
                        .fill(TT.ink.opacity(0.18))
                        .padding(.top, height * 0.24)
                )
                .overlay(Capsule().stroke(TT.ink, lineWidth: height * 0.025))
                .frame(width: height * 0.56, height: height * 0.5)
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

/// A single beat of the victory dance: how far the avatar hops, how much it
/// leans/rotates, and how squashed or stretched it is at that instant.
private struct DancePhase {
    var yOffset: CGFloat
    var rotation: Double
    var scaleX: CGFloat
    var scaleY: CGFloat
    var animation: Animation
}

private struct VictoryDanceModifier: ViewModifier {
    private let phases: [DancePhase] = [
        // Anticipation crouch
        DancePhase(yOffset: 3, rotation: -4, scaleX: 1.10, scaleY: 0.90,
                   animation: .easeIn(duration: 0.14)),
        // Big hop left
        DancePhase(yOffset: -26, rotation: -12, scaleX: 0.92, scaleY: 1.10,
                   animation: .interpolatingSpring(stiffness: 260, damping: 12)),
        // Land, squash
        DancePhase(yOffset: 2, rotation: -6, scaleX: 1.14, scaleY: 0.88,
                   animation: .easeOut(duration: 0.1)),
        // Anticipation crouch, other way
        DancePhase(yOffset: 3, rotation: 4, scaleX: 1.10, scaleY: 0.90,
                   animation: .easeIn(duration: 0.14)),
        // Big hop right
        DancePhase(yOffset: -26, rotation: 12, scaleX: 0.92, scaleY: 1.10,
                   animation: .interpolatingSpring(stiffness: 260, damping: 12)),
        // Land, squash
        DancePhase(yOffset: 2, rotation: 6, scaleX: 1.14, scaleY: 0.88,
                   animation: .easeOut(duration: 0.1)),
        // Neutral rest beat before the loop repeats
        DancePhase(yOffset: 0, rotation: 0, scaleX: 1, scaleY: 1,
                   animation: .easeInOut(duration: 0.16)),
    ]

    func body(content: Content) -> some View {
        content.phaseAnimator(phases.indices, content: { view, index in
            let phase = phases[index]
            view
                .scaleEffect(x: phase.scaleX, y: phase.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(phase.rotation), anchor: .bottom)
                .offset(y: phase.yOffset)
        }, animation: { index in
            phases[index].animation
        })
    }
}

extension View {
    /// A looping, genuinely bouncy victory-dance animation — hop, squash,
    /// lean, repeat — for the winner's avatar on the victory screen.
    func victoryDance() -> some View {
        modifier(VictoryDanceModifier())
    }
}
