//
//  RootView.swift
//  Travel Trivia
//

import SwiftUI

struct RootView: View {
    @Environment(GameEngine.self) private var engine

    var body: some View {
        ZStack {
            SkyBackdrop()
            switch engine.phase {
            case .ride:
                OurRideView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            case .playing:
                QuestionView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            case .victory:
                VictoryView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .opacity))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: engine.phase)
        .onAppear {
            #if DEBUG
            engine.debugApplyLaunchArguments(ProcessInfo.processInfo.arguments)
            #endif
        }
    }
}

/// Flat comic sky with chunky sticker clouds — no gradients anywhere.
struct SkyBackdrop: View {
    var body: some View {
        ZStack {
            TT.sky.ignoresSafeArea()
            GeometryReader { proxy in
                let w = proxy.size.width
                ComicCloud(width: 110)
                    .position(x: w * 0.16, y: 90)
                ComicCloud(width: 74)
                    .position(x: w * 0.85, y: 150)
                ComicCloud(width: 90)
                    .position(x: w * 0.72, y: proxy.size.height * 0.82)
            }
            .ignoresSafeArea()
        }
    }
}

struct ComicCloud: View {
    var width: CGFloat

    var body: some View {
        let h = width * 0.42
        ZStack {
            cloudShape.offset(y: 4).foregroundStyle(TT.skyDeep)
            cloudShape.foregroundStyle(.white)
        }
        .frame(width: width, height: h * 1.5)
        .opacity(0.9)
    }

    private var cloudShape: some View {
        let h = width * 0.42
        return ZStack {
            Capsule().frame(width: width, height: h)
            Circle().frame(width: h * 1.15).offset(x: -width * 0.16, y: -h * 0.42)
            Circle().frame(width: h * 0.9).offset(x: width * 0.15, y: -h * 0.32)
        }
    }
}
