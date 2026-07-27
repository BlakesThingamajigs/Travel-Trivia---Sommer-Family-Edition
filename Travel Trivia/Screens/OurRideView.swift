//
//  OurRideView.swift
//  Travel Trivia
//
//  The seat picker: a top-down car on the road. In a real party every
//  device claims (or moves to) a seat and the host syncs the arrangement
//  to the whole car; in practice mode the open seat "joins" the 4th mock
//  player, exactly as in session 1.
//

import SwiftUI

struct OurRideView: View {
    @Environment(GameEngine.self) private var engine

    private var unseated: [Player] {
        engine.players.filter { !$0.isSeated && $0.presence != .left }
    }

    var body: some View {
        VStack(spacing: 8) {
            StickerText(text: "OUR RIDE", size: 44)
                .padding(.top, 8)
                .zIndex(1)
            StickerChip(text: "Pick your seats, gang!", textSize: 14)

            Spacer(minLength: 12)

            CarTopDownView()
                .overlay {
                    ConfettiBurst(trigger: engine.joinTrigger, origin: .init(x: 0.5, y: 0.6))
                }

            if !unseated.isEmpty {
                HStack(spacing: 14) {
                    ForEach(unseated, id: \.persistentModelID) { player in
                        VStack(spacing: 2) {
                            AvatarHead(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                                       expression: .idle, size: 34)
                            StickerChip(text: player.isUser ? "YOU" : player.name,
                                        textSize: 9)
                        }
                    }
                    StickerChip(text: "STILL PICKING…", fill: TT.sunshine, textSize: 10)
                }
                .padding(.top, 6)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer(minLength: 12)

            footer
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 20)
        .background {
            RoadStrip(width: 384)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: unseated.count)
    }

    @ViewBuilder
    private var footer: some View {
        if engine.canControlFlow {
            Button {
                engine.startGame()
            } label: {
                RoadSignLabel(title: "Start the Trip")
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("start-trip")
        } else {
            StickerChip(text: "THE HOST STARTS THE TRIP…",
                        fill: TT.sunshine, textSize: 12)
                .padding(.vertical, 12)
                .accessibilityIdentifier("ride-waiting")
        }
    }
}

private struct CarTopDownView: View {
    @Environment(GameEngine.self) private var engine

    private let carWidth: CGFloat = 300
    private let carHeight: CGFloat = 420

    var body: some View {
        ZStack {
            wheels
            carBody
            seats
        }
        .frame(width: carWidth + 84, height: carHeight + 40)
    }

    private var carBody: some View {
        ZStack {
            let body = RoundedRectangle(cornerRadius: 72)
            body.fill(TT.ink)
                .offset(y: 7)
            body.fill(TT.cherry)
            body.strokeBorder(TT.ink, lineWidth: 4.5)
            // Windshield up front
            UnevenRoundedRectangle(topLeadingRadius: 34, bottomLeadingRadius: 12,
                                   bottomTrailingRadius: 12, topTrailingRadius: 34)
                .fill(TT.paper)
                .stroke(TT.ink, lineWidth: 3.5)
                .frame(width: carWidth * 0.62, height: 44)
                .offset(y: -carHeight * 0.38)
            // Rear window
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 26,
                                   bottomTrailingRadius: 26, topTrailingRadius: 10)
                .fill(TT.paper)
                .stroke(TT.ink, lineWidth: 3.5)
                .frame(width: carWidth * 0.56, height: 34)
                .offset(y: carHeight * 0.40)
            // Headlights
            headlight.offset(x: -carWidth * 0.30, y: -carHeight * 0.475)
            headlight.offset(x: carWidth * 0.30, y: -carHeight * 0.475)
        }
        .frame(width: carWidth, height: carHeight)
    }

    private var headlight: some View {
        Capsule()
            .fill(TT.sunshine)
            .overlay(Capsule().stroke(TT.ink, lineWidth: 3))
            .frame(width: 44, height: 16)
    }

    private var wheels: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                let isLeft = i % 2 == 0
                let isFront = i < 2
                RoundedRectangle(cornerRadius: 10)
                    .fill(TT.asphalt)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(TT.ink, lineWidth: 3.5))
                    .frame(width: 26, height: 72)
                    .offset(x: (isLeft ? -1 : 1) * (carWidth / 2 + 8),
                            y: (isFront ? -1 : 1) * carHeight * 0.27)
            }
        }
    }

    private var seats: some View {
        VStack(spacing: 34) {
            HStack(spacing: 44) {
                seatView(index: 0)
                seatView(index: 1)
            }
            HStack(spacing: 44) {
                seatView(index: 2)
                seatView(index: 3)
            }
        }
        .offset(y: 6)
    }

    @ViewBuilder
    private func seatView(index: Int) -> some View {
        let player = engine.players.first { $0.seatIndex == index && $0.presence != .left }
        ZStack {
            SeatBase()
            if let player {
                OccupiedSeat(player: player)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            } else if engine.playContext == .practice {
                // Session-1 slice: the open seat joins the 4th mock player.
                OpenSeat(label: "TAP TO JOIN") {
                    engine.joinOpenSeat()
                }
            } else {
                // Real party: any free seat is up for grabs for *you*
                // (tapping a different one moves you; the host arbitrates).
                OpenSeat(label: "TAP TO SIT") {
                    engine.requestSeat(index)
                }
            }
        }
        .frame(width: 104, height: 118)
        .animation(.spring(response: 0.45, dampingFraction: 0.5), value: player != nil)
    }
}

private struct SeatBase: View {
    var body: some View {
        VStack(spacing: -8) {
            // Headrest
            Capsule()
                .fill(TT.asphalt)
                .overlay(Capsule().stroke(TT.ink, lineWidth: 3))
                .frame(width: 52, height: 20)
            RoundedRectangle(cornerRadius: 18)
                .fill(TT.asphalt)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(TT.ink, lineWidth: 3.5))
                .frame(width: 92, height: 96)
        }
    }
}

private struct OccupiedSeat: View {
    var player: Player

    private var dropped: Bool { player.presence == .dropped }

    var body: some View {
        VStack(spacing: -2) {
            AvatarFullBody(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                           expression: dropped ? .sad : .happy,
                           height: 84)
            StickerChip(text: player.isUser ? "\(player.name) (You)" : player.name,
                        fill: player.isUser ? TT.sunshine : TT.paper,
                        textSize: 11)
        }
        .offset(y: 8)
        .opacity(dropped ? 0.45 : 1)
        .saturation(dropped ? 0.25 : 1)
        .overlay(alignment: .top) {
            if dropped {
                StickerChip(text: "BACK SOON…", fill: TT.tangerine,
                            textColor: .white, textSize: 8)
                    .rotationEffect(.degrees(-8))
                    .offset(y: -4)
            }
            if let badge = player.role.badge, !dropped {
                StickerChip(text: badge,
                            fill: player.role == .pilot ? TT.cherry : TT.skyDeep,
                            textColor: .white, textSize: 8)
                    .rotationEffect(.degrees(-8))
                    .offset(y: -6)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: dropped)
    }
}

private struct OpenSeat: View {
    var label: String = "TAP TO JOIN"
    var join: () -> Void
    @State private var pulsing = false

    var body: some View {
        Button(action: join) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(TT.paper, style: StrokeStyle(lineWidth: 3, dash: [7, 6]))
                        .frame(width: 84, height: 66)
                    Text("+")
                        .font(TT.font(38, .black))
                        .foregroundStyle(TT.paper)
                        .scaleEffect(pulsing ? 1.18 : 0.94)
                }
                StickerChip(text: label, fill: TT.lime, textColor: .white, textSize: 10)
            }
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("seat-open")
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

/// Vertical stretch of road under the car.
private struct RoadStrip: View {
    var width: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(TT.asphalt)
                .overlay(alignment: .leading) { Rectangle().fill(TT.ink).frame(width: 5) }
                .overlay(alignment: .trailing) { Rectangle().fill(TT.ink).frame(width: 5) }
            // Dashed center line
            VStack(spacing: 26) {
                ForEach(0..<14, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(TT.sunshine)
                        .frame(width: 10, height: 42)
                }
            }
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
