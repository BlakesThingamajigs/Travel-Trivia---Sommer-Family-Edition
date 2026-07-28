//
//  PlayAnotherRoundView.swift
//  Travel Trivia
//
//  Victory's host-only "Play Another Round": reuses Create Game's
//  mode/genre/difficulty cards, defaulting to the settings the party just
//  played, with a one-tap shortcut to keep them unchanged.
//

import SwiftUI

struct PlayAnotherRoundPicker: View {
    @Environment(AppModel.self) private var app

    var currentConfig: PartyConfig
    var onStart: (PartyConfig) -> Void
    var onCancel: () -> Void

    private enum Step: Int {
        case mode, genre, difficulty
    }

    @State private var step: Step = .mode
    @State private var selectedMode: GameMode?
    @State private var selectedGenre: TriviaGenre?

    var body: some View {
        VStack(spacing: 14) {
            FlowHeader(title: headerTitle, onBack: goBack)
                .padding(.horizontal, 20)
            StickerChip(text: "STEP \(step.rawValue + 1) OF 3", textSize: 11)

            if step == .mode {
                Button(action: keepCurrentAndStart) {
                    StickerChip(text: "KEEP \(currentConfig.modeName.uppercased()) · \(currentConfig.genreName.uppercased())",
                                fill: TT.sunshine, textSize: 12)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("keep-current-round-settings")
            }

            switch step {
            case .mode: modeStep
            case .genre: genreStep
            case .difficulty: difficultyStep
            }
        }
        .padding(.vertical, 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: step)
    }

    private var headerTitle: String {
        switch step {
        case .mode: "NEXT ROUND: MODE"
        case .genre: "NEXT ROUND: GENRE"
        case .difficulty: "NEXT ROUND: DIFFICULTY"
        }
    }

    private func goBack() {
        switch step {
        case .mode: onCancel()
        case .genre: step = .mode
        case .difficulty: step = .genre
        }
    }

    private var modeStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(app.catalog.modes) { mode in
                    ModeCard(mode: mode) {
                        selectedMode = mode
                        step = .genre
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var genreStep: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 14) {
                ForEach(app.catalog.genres) { genre in
                    GenreCard(genre: genre) {
                        selectedGenre = genre
                        step = .difficulty
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
    }

    private var difficultyStep: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            ForEach(DifficultyTier.allCases) { tier in
                DifficultyCard(tier: tier) {
                    finish(difficulty: tier)
                }
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private func keepCurrentAndStart() {
        onStart(currentConfig)
    }

    private func finish(difficulty: DifficultyTier) {
        guard let mode = selectedMode, let genre = selectedGenre else { return }
        let config = PartyConfig(modeSlug: mode.slug, modeName: mode.displayName,
                                 genreSlug: genre.slug, genreName: genre.displayName,
                                 difficulty: difficulty, minPlayers: mode.minPlayers,
                                 requiresEvenPlayers: mode.requiresEvenPlayers)
        onStart(config)
    }
}
