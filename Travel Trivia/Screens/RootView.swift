//
//  RootView.swift
//  Travel Trivia
//

import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(GameEngine.self) private var engine

    var body: some View {
        ZStack {
            SkyBackdrop()
            content
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: app.route)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: engine.phase)
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: inLobby)
        .onAppear {
            #if DEBUG
            app.debugApplyLaunchArguments(ProcessInfo.processInfo.arguments)
            #endif
        }
    }

    private var inLobby: Bool {
        app.route == .party && app.party.state?.phase == .lobby
    }

    @ViewBuilder
    private var content: some View {
        switch app.route {
        case .menu:
            MainMenuView()
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        case .createGame:
            CreateGameFlow()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .joinGame:
            JoinGameView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .settings:
            SettingsView()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .party:
            partyContent
        case .practice:
            gamePhases
        }
    }

    @ViewBuilder
    private var partyContent: some View {
        if inLobby {
            LobbyView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if app.party.state != nil {
            gamePhases
        } else {
            // Shouldn't linger: the party closed and the model routes to
            // the menu, but never render a dead screen in the gap.
            MainMenuView()
        }
    }

    @ViewBuilder
    private var gamePhases: some View {
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
