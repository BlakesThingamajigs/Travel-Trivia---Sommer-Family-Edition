//
//  ConfettiView.swift
//  Travel Trivia
//
//  Pure-SwiftUI confetti burst (Canvas + TimelineView). This is a stopgap
//  until the Rive pipeline exists; the API (fire on trigger change) is
//  designed so a Rive-driven version can swap in behind the same call site.
//

import SwiftUI

struct ConfettiBurst: View {
    /// Fires a new burst whenever this value changes.
    var trigger: Int
    /// Where in the container the burst originates.
    var origin: UnitPoint = .init(x: 0.5, y: 0.35)
    var pieceCount: Int = 30

    @State private var burst: Burst?

    private struct Piece {
        var angle: Double
        var speed: Double
        var size: CGFloat
        var color: Color
        var spin: Double
        var isRound: Bool
    }

    private struct Burst {
        var start: Date
        var pieces: [Piece]
    }

    private static let colors: [Color] = [
        TT.sunshine, TT.tangerine, TT.cherry, TT.lime, TT.grape, TT.bubblegum, .white,
    ]

    private static let lifetime: Double = 1.6

    var body: some View {
        ZStack {
            if let burst {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        draw(burst: burst, at: timeline.date, in: &context, size: size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            burst = Burst(start: .now, pieces: (0..<pieceCount).map { _ in
                Piece(
                    angle: Double.random(in: 0..<(2 * .pi)),
                    speed: Double.random(in: 240...620),
                    size: CGFloat.random(in: 7...14),
                    color: Self.colors.randomElement()!,
                    spin: Double.random(in: -10...10),
                    isRound: Bool.random()
                )
            })
            Task {
                try? await Task.sleep(for: .seconds(Self.lifetime + 0.2))
                burst = nil
            }
        }
    }

    private func draw(burst: Burst, at date: Date, in context: inout GraphicsContext, size: CGSize) {
        let t = date.timeIntervalSince(burst.start)
        guard t >= 0, t < Self.lifetime else { return }
        let gravity: Double = 950
        let originPoint = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let fade = t > Self.lifetime - 0.4 ? (Self.lifetime - t) / 0.4 : 1

        for piece in burst.pieces {
            let x = originPoint.x + cos(piece.angle) * piece.speed * t
            let y = originPoint.y + sin(piece.angle) * piece.speed * t * 0.85 + 0.5 * gravity * t * t
            guard y < size.height + 20 else { continue }

            var pieceContext = context
            pieceContext.opacity = fade
            pieceContext.translateBy(x: x, y: y)
            pieceContext.rotate(by: .radians(piece.spin * t))

            let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2,
                              width: piece.size, height: piece.size * (piece.isRound ? 1 : 0.62))
            let path = piece.isRound ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 2)
            pieceContext.fill(path, with: .color(piece.color))
            pieceContext.stroke(path, with: .color(TT.ink), lineWidth: 1.4)
        }
    }
}
