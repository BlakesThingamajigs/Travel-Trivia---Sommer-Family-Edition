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
        case mode, genre, difficulty, questionCount
    }

    @State private var step: Step = .mode
    @State private var selectedMode: GameMode?
    @State private var selectedGenre: TriviaGenre?
    @State private var selectedDifficulty: DifficultyTier?
    @State private var questionCount = 0

    /// Mirrors CreateGameFlow: Would You Rather always plays its own genre,
    /// so genre selection is skipped here too.
    private var isWouldYouRatherFlow: Bool {
        selectedMode?.slug == WouldYouRatherMode.modeSlug
    }
    private var displayStepIndex: Int {
        guard isWouldYouRatherFlow else { return step.rawValue }
        switch step {
        case .mode: return 0
        case .difficulty: return 1
        case .questionCount: return 2
        case .genre: return step.rawValue
        }
    }
    private var displayStepCount: Int { isWouldYouRatherFlow ? 3 : 4 }

    var body: some View {
        VStack(spacing: 14) {
            FlowHeader(title: headerTitle, onBack: goBack)
                .padding(.horizontal, 20)
            StickerChip(text: "STEP \(displayStepIndex + 1) OF \(displayStepCount)", textSize: 11)

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
            case .questionCount: questionCountStep
            }
        }
        .padding(.vertical, 10)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: step)
        .onAppear {
            if questionCount == 0 { questionCount = app.profile.lastQuestionCount }
        }
    }

    private var headerTitle: String {
        switch step {
        case .mode: "NEXT ROUND: MODE"
        case .genre: "NEXT ROUND: GENRE"
        case .difficulty: "NEXT ROUND: DIFFICULTY"
        case .questionCount: "NEXT ROUND: LENGTH"
        }
    }

    private func goBack() {
        switch step {
        case .mode: onCancel()
        case .genre: step = .mode
        case .difficulty: step = isWouldYouRatherFlow ? .mode : .genre
        case .questionCount: step = .difficulty
        }
    }

    private var modeStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(app.catalog.modes) { mode in
                    ModeCard(mode: mode) {
                        selectedMode = mode
                        if mode.slug == WouldYouRatherMode.modeSlug {
                            selectedGenre = app.catalog.genre(slug: WouldYouRatherMode.genreSlug)
                            step = .difficulty
                        } else {
                            step = .genre
                        }
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
                    selectedDifficulty = tier
                    step = .questionCount
                }
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private var questionCountStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            QuestionCountControl(count: $questionCount)
            Button(action: finish) {
                RoadSignLabel(title: "Start Round")
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("play-another-round-start")
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private func keepCurrentAndStart() {
        onStart(currentConfig)
    }

    private func finish() {
        guard let mode = selectedMode, let genre = selectedGenre, let difficulty = selectedDifficulty else { return }
        let config = PartyConfig(modeSlug: mode.slug, modeName: mode.displayName,
                                 genreSlug: genre.slug, genreName: genre.displayName,
                                 difficulty: difficulty, minPlayers: mode.minPlayers,
                                 requiresEvenPlayers: mode.requiresEvenPlayers,
                                 questionCount: questionCount)
        app.profile.lastQuestionCount = questionCount
        onStart(config)
    }
}
