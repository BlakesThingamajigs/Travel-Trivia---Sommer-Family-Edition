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
    @State private var app: AppModel

    init() {
        // Party/session state models a live in-car party — deliberately
        // in-memory only; nothing here should outlive the app session yet.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Player.self, configurations: configuration)
        self.container = container
        _app = State(initialValue: AppModel(engine: GameEngine(context: container.mainContext)))
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
