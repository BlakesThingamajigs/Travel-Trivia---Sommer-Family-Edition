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
    /// My Garage cosmetics — all default to "none" (or the base look) so
    /// every existing call site keeps rendering exactly as before without
    /// passing these.
    var hatID: String = "hat-none"
    var accessoryID: String = "acc-none"
    var stickerID: String = "sticker-none"
    var hairID: String = "hair-none"
    var faceMarkID: String = "face-none"
    var headShapeID: String = "shape-round"

    // Idle life: a slow breathing scale/bob and the occasional blink, kept
    // subtle enough that a whole row of avatars doesn't turn into a wall of
    // motion.
    @State private var breathing = false
    @State private var blinking = false

    var body: some View {
        ZStack {
            headSilhouette
            hairOverlay
            face
            cheekSticker
            faceMarkOverlay
            accessoryOverlay
            hatOverlay
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

    // MARK: Head shape (real body-shape variety, not just accessories)

    @ViewBuilder
    private var headSilhouette: some View {
        // Sticker ring (ink drop-shadow + white halo) behind the head,
        // shape-matched so a square/star head doesn't peek a circular
        // halo out from behind its corners.
        switch headShapeID {
        case "shape-square":
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(TT.ink)
                .frame(width: size + 8, height: size + 8)
                .offset(y: 3)
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(.white)
                .frame(width: size + 8, height: size + 8)
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: size * 0.22).stroke(TT.ink, lineWidth: size * 0.06))
                .frame(width: size, height: size)
        case "shape-star":
            StarShape()
                .fill(TT.ink)
                .frame(width: size + 10, height: size + 10)
                .offset(y: 3)
            StarShape()
                .fill(.white)
                .frame(width: size + 10, height: size + 10)
            StarShape()
                .fill(color)
                .overlay(StarShape().stroke(TT.ink, lineWidth: size * 0.06))
                .frame(width: size * 1.06, height: size * 1.06)
        default:
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

    // MARK: My Garage cosmetics (hat / accessory / cheek sticker overlays)

    @ViewBuilder
    private var hatOverlay: some View {
        switch hatID {
        case "hat-cap":
            Capsule()
                .fill(TT.skyDeep)
                .overlay(Capsule().stroke(TT.ink, lineWidth: size * 0.05))
                .frame(width: size * 0.62, height: size * 0.24)
                .offset(y: -size * 0.52)
        case "hat-party":
            Triangle()
                .fill(TT.bubblegum)
                .overlay(Triangle().stroke(TT.ink, lineWidth: size * 0.05))
                .frame(width: size * 0.4, height: size * 0.44)
                .overlay(alignment: .top) {
                    Circle().fill(TT.sunshine).frame(width: size * 0.1, height: size * 0.1)
                        .offset(y: -size * 0.05)
                }
                .offset(y: -size * 0.56)
        case "hat-crown":
            CrownShape()
                .fill(TT.sunshine)
                .overlay(CrownShape().stroke(TT.ink, lineWidth: size * 0.045))
                .frame(width: size * 0.6, height: size * 0.26)
                .offset(y: -size * 0.5)
        case "hat-beanie":
            UnevenRoundedRectangle(topLeadingRadius: size * 0.3, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: size * 0.3)
                .fill(TT.grape)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: size * 0.3, bottomLeadingRadius: 0,
                                               bottomTrailingRadius: 0, topTrailingRadius: size * 0.3)
                    .stroke(TT.ink, lineWidth: size * 0.05))
                .frame(width: size * 0.66, height: size * 0.34)
                .overlay(alignment: .top) {
                    Circle().fill(TT.sunshine).frame(width: size * 0.12, height: size * 0.12)
                        .offset(y: -size * 0.06)
                }
                .offset(y: -size * 0.44)
        case "hat-cowboy":
            ZStack {
                Ellipse()
                    .fill(TT.tangerine)
                    .overlay(Ellipse().stroke(TT.ink, lineWidth: size * 0.045))
                    .frame(width: size * 0.86, height: size * 0.2)
                    .offset(y: size * 0.08)
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(TT.tangerine)
                    .overlay(RoundedRectangle(cornerRadius: size * 0.12).stroke(TT.ink, lineWidth: size * 0.045))
                    .frame(width: size * 0.4, height: size * 0.26)
                    .offset(y: -size * 0.08)
            }
            .offset(y: -size * 0.5)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var accessoryOverlay: some View {
        switch accessoryID {
        case "acc-shades":
            HStack(spacing: size * 0.05) {
                RoundedRectangle(cornerRadius: size * 0.03).fill(TT.ink)
                    .frame(width: size * 0.2, height: size * 0.13)
                RoundedRectangle(cornerRadius: size * 0.03).fill(TT.ink)
                    .frame(width: size * 0.2, height: size * 0.13)
            }
            .offset(y: -size * 0.09)
        case "acc-bowtie":
            BowtieShape()
                .fill(TT.cherry)
                .overlay(BowtieShape().stroke(TT.ink, lineWidth: size * 0.04))
                .frame(width: size * 0.34, height: size * 0.18)
                .offset(y: size * 0.46)
        case "acc-flower":
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Ellipse()
                        .fill(TT.bubblegum)
                        .frame(width: size * 0.14, height: size * 0.08)
                        .rotationEffect(.degrees(Double(i) * 72))
                }
                Circle().fill(TT.sunshine).frame(width: size * 0.1, height: size * 0.1)
            }
            .offset(y: -size * 0.5)
        case "acc-scarf":
            RoundedRectangle(cornerRadius: size * 0.06)
                .fill(TT.grape)
                .overlay(RoundedRectangle(cornerRadius: size * 0.06).stroke(TT.ink, lineWidth: size * 0.04))
                .frame(width: size * 0.7, height: size * 0.16)
                .offset(y: size * 0.42)
        case "acc-headphones":
            ZStack {
                Capsule()
                    .stroke(TT.ink, lineWidth: size * 0.05)
                    .frame(width: size * 0.7, height: size * 0.5)
                    .offset(y: -size * 0.18)
                HStack(spacing: size * 0.62) {
                    Circle().fill(TT.ink).frame(width: size * 0.16, height: size * 0.16)
                    Circle().fill(TT.ink).frame(width: size * 0.16, height: size * 0.16)
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var cheekSticker: some View {
        switch stickerID {
        case "sticker-star":
            StarShape()
                .fill(TT.sunshine)
                .frame(width: size * 0.16, height: size * 0.16)
                .offset(x: size * 0.28, y: size * 0.08)
        case "sticker-heart":
            HeartShape()
                .fill(TT.cherry)
                .frame(width: size * 0.16, height: size * 0.15)
                .offset(x: size * 0.28, y: size * 0.08)
        case "sticker-lightning":
            LightningShape()
                .fill(TT.sunshine)
                .stroke(TT.ink, lineWidth: size * 0.02)
                .frame(width: size * 0.14, height: size * 0.2)
                .offset(x: size * 0.28, y: size * 0.06)
        case "sticker-rainbow":
            ZStack {
                RainbowArc(colors: [TT.cherry, TT.sunshine, TT.lime])
                    .frame(width: size * 0.2, height: size * 0.14)
            }
            .offset(x: size * 0.28, y: size * 0.09)
        case "sticker-paw":
            ZStack {
                Ellipse().fill(TT.grape).frame(width: size * 0.1, height: size * 0.08)
                    .offset(y: size * 0.03)
                HStack(spacing: size * 0.02) {
                    Circle().fill(TT.grape).frame(width: size * 0.035, height: size * 0.035)
                    Circle().fill(TT.grape).frame(width: size * 0.035, height: size * 0.035)
                    Circle().fill(TT.grape).frame(width: size * 0.035, height: size * 0.035)
                }
                .offset(y: -size * 0.05)
            }
            .offset(x: size * 0.28, y: size * 0.08)
        default:
            EmptyView()
        }
    }

    // MARK: My Garage cosmetics (hair / face mark — new categories)

    @ViewBuilder
    private var hairOverlay: some View {
        switch hairID {
        case "hair-mohawk":
            Triangle()
                .fill(TT.ink)
                .frame(width: size * 0.16, height: size * 0.3)
                .offset(y: -size * 0.56)
        case "hair-ponytail":
            Ellipse()
                .fill(TT.ink)
                .frame(width: size * 0.14, height: size * 0.3)
                .rotationEffect(.degrees(20))
                .offset(x: size * 0.42, y: -size * 0.28)
        case "hair-curls":
            HStack(spacing: -size * 0.03) {
                ForEach(0..<4, id: \.self) { _ in
                    Circle().fill(TT.ink).frame(width: size * 0.16, height: size * 0.16)
                }
            }
            .offset(y: -size * 0.46)
        case "hair-spiky":
            HStack(spacing: size * 0.02) {
                ForEach(0..<3, id: \.self) { i in
                    Triangle()
                        .fill(TT.ink)
                        .frame(width: size * 0.14, height: size * 0.22)
                        .rotationEffect(.degrees(i == 1 ? 0 : (i == 0 ? -14 : 14)))
                }
            }
            .offset(y: -size * 0.52)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var faceMarkOverlay: some View {
        switch faceMarkID {
        case "face-freckles":
            HStack(spacing: size * 0.5) {
                freckleCluster
                freckleCluster
            }
            .offset(y: size * 0.02)
        case "face-mustache":
            Capsule()
                .fill(TT.ink)
                .frame(width: size * 0.24, height: size * 0.06)
                .offset(y: size * 0.135)
        case "face-monocle":
            Circle()
                .stroke(TT.sunshine, lineWidth: size * 0.035)
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: -size * 0.14, y: -size * 0.09)
        default:
            EmptyView()
        }
    }

    private var freckleCluster: some View {
        HStack(spacing: size * 0.025) {
            ForEach(0..<3, id: \.self) { _ in
                Circle().fill(TT.tangerine.opacity(0.7)).frame(width: size * 0.025, height: size * 0.025)
            }
        }
    }
}

// MARK: - Small cosmetic glyph shapes

nonisolated private struct Triangle: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

nonisolated private struct CrownShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let peaks = 3
        let step = rect.width / CGFloat(peaks)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0..<peaks {
            let x0 = rect.minX + step * CGFloat(i)
            let xMid = x0 + step / 2
            let x1 = x0 + step
            path.addLine(to: CGPoint(x: xMid, y: rect.minY))
            path.addLine(to: CGPoint(x: x1, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

nonisolated private struct BowtieShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        var right = Path()
        right.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        right.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
        right.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        right.closeSubpath()
        path.addPath(right)
        return path
    }
}

nonisolated private struct StarShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        var path = Path()
        for i in 0..<10 {
            let radius = i % 2 == 0 ? outer : inner
            let angle = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius,
                                y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

nonisolated private struct HeartShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: h * 0.95))
        path.addCurve(to: CGPoint(x: rect.minX, y: h * 0.32),
                      control1: CGPoint(x: rect.midX - w * 0.1, y: h * 0.75),
                      control2: CGPoint(x: rect.minX, y: h * 0.55))
        path.addArc(center: CGPoint(x: w * 0.25, y: h * 0.28), radius: w * 0.25,
                    startAngle: .degrees(150), endAngle: .degrees(-20), clockwise: false)
        path.addArc(center: CGPoint(x: w * 0.75, y: h * 0.28), radius: w * 0.25,
                    startAngle: .degrees(200), endAngle: .degrees(30), clockwise: false)
        path.addCurve(to: CGPoint(x: rect.midX, y: h * 0.95),
                      control1: CGPoint(x: rect.maxX, y: h * 0.55),
                      control2: CGPoint(x: rect.midX + w * 0.1, y: h * 0.75))
        path.closeSubpath()
        return path
    }
}

nonisolated private struct LightningShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.6, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY * 1.1))
        path.addLine(to: CGPoint(x: rect.midX * 0.9, y: rect.midY * 1.1))
        path.addLine(to: CGPoint(x: rect.minX * 1.2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY * 0.75))
        path.addLine(to: CGPoint(x: rect.midX * 1.1, y: rect.midY * 0.75))
        path.closeSubpath()
        return path
    }
}

/// Three stacked arcs for the Rainbow Cheek sticker.
nonisolated private struct RainbowArc: View {
    var colors: [Color]

    var body: some View {
        ZStack {
            ForEach(colors.indices, id: \.self) { i in
                MouthShape(curve: -1.0)
                    .stroke(colors[i], style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .scaleEffect(1.0 - CGFloat(i) * 0.28)
                    .offset(y: CGFloat(i) * 2)
            }
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
    var hatID: String = "hat-none"
    var accessoryID: String = "acc-none"
    var stickerID: String = "sticker-none"
    var hairID: String = "hair-none"
    var faceMarkID: String = "face-none"
    var headShapeID: String = "shape-round"

    var body: some View {
        VStack(spacing: -height * 0.05) {
            AvatarHead(color: color, expression: expression, size: height * 0.42,
                       hatID: hatID, accessoryID: accessoryID, stickerID: stickerID,
                       hairID: hairID, faceMarkID: faceMarkID, headShapeID: headShapeID)
                .zIndex(1)
            // Body: wider than the head so the silhouette reads as
            // shoulders rather than a second, equally sized blob stacked on
            // the first (the "peanut head" look). Shape matches the head —
            // real body variety, not just a cosmetic bolted onto the same
            // capsule.
            torso
        }
        .frame(height: height)
    }

    @ViewBuilder
    private var torso: some View {
        switch headShapeID {
        case "shape-square":
            RoundedRectangle(cornerRadius: height * 0.1)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.1)
                        .fill(TT.ink.opacity(0.18))
                        .padding(.top, height * 0.24)
                )
                .overlay(RoundedRectangle(cornerRadius: height * 0.1).stroke(TT.ink, lineWidth: height * 0.025))
                .frame(width: height * 0.56, height: height * 0.5)
        case "shape-star":
            StarShape()
                .fill(color)
                .overlay(StarShape().stroke(TT.ink, lineWidth: height * 0.025))
                .frame(width: height * 0.58, height: height * 0.5)
        default:
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
