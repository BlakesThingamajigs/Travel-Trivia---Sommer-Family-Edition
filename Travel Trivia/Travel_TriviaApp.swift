//
//  Travel_TriviaApp.swift
//  Travel Trivia
//
//  Created by Blake Sommer on 7/26/26.
//

import SwiftUI
import SwiftData

@main
struct Travel_TriviaApp: App {
    private let container: ModelContainer
    /// Local-only progression (My Garage cosmetics + earned badges) — the
    /// one piece of state that's meant to survive relaunches on this
    /// device, so it gets its own disk-backed container instead of sharing
    /// the in-memory party mirror below.
    private let progressContainer: ModelContainer
    @State private var app: AppModel

    init() {
        // Party/session state models a live in-car party — deliberately
        // in-memory only; nothing here should outlive the app session yet.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Player.self, configurations: configuration)
        self.container = container

        let progressContainer = try! ModelContainer(
            for: AvatarLoadout.self, CarLoadout.self, EarnedBadge.self)
        self.progressContainer = progressContainer

        let profile = LocalProfile()
        let progress = ProgressStore(context: progressContainer.mainContext, playerID: profile.playerID)
        _app = State(initialValue: AppModel(engine: GameEngine(context: container.mainContext),
                                            profile: profile, progress: progress))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.engine)
                .task {
                    await app.catalog.refresh()
                }
        }
        .modelContainer(container)
    }
}
