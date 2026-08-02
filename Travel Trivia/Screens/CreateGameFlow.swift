//
//  CreateGameFlow.swift
//  Travel Trivia
//
//  Create a New Game: mode → genre → difficulty → name the party, then the
//  host starts advertising and lands in the Lobby. The full roadmap of
//  modes and genres stays visible — anything without real gameplay or
//  content yet is grayed out as Coming Soon, not hidden.
//

import SwiftUI

struct CreateGameFlow: View {
    @Environment(AppModel.self) private var app

    private enum Step: Int {
        case mode, genre, difficulty, name
    }

    @State private var step: Step = .mode
    @State private var selectedMode: GameMode?
    @State private var selectedGenre: TriviaGenre?
    @State private var selectedDifficulty: DifficultyTier?
    @State private var partyName = ""
    @State private var code = String(Int.random(in: 1000...9999))
    @State private var questionCount = 0

    /// Would You Rather always plays its own genre — genre selection is
    /// skipped for this mode only (see CreateGameFlow's file header /
    /// WouldYouRatherMode).
    private var isWouldYouRatherFlow: Bool {
        selectedMode?.slug == WouldYouRatherMode.modeSlug
    }

    /// Step numbering collapses to 3 steps (mode/difficulty/name) when the
    /// genre step is skipped, so "STEP X OF Y" stays accurate instead of
    /// jumping from 1 to 3.
    private var displayStepIndex: Int {
        guard isWouldYouRatherFlow else { return step.rawValue }
        switch step {
        case .mode: return 0
        case .difficulty: return 1
        case .name: return 2
        case .genre: return step.rawValue
        }
    }
    private var displayStepCount: Int { isWouldYouRatherFlow ? 3 : 4 }

    var body: some View {
        VStack(spacing: 14) {
            FlowHeader(title: headerTitle, onBack: goBack)
                .padding(.horizontal, 20)
            StickerChip(text: "STEP \(displayStepIndex + 1) OF \(displayStepCount)", textSize: 11)

            switch step {
            case .mode: modeStep
            case .genre: genreStep
            case .difficulty: difficultyStep
            case .name: nameStep
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
        case .mode: "GAME TYPE"
        case .genre: "PICK A GENRE"
        case .difficulty: "DIFFICULTY"
        case .name: "NAME YOUR PARTY"
        }
    }

    private func goBack() {
        switch step {
        case .mode: app.route = .menu
        case .genre: step = .mode
        case .difficulty: step = isWouldYouRatherFlow ? .mode : .genre
        case .name: step = .difficulty
        }
    }

    // MARK: Step 1 — mode

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

    // MARK: Step 2 — genre

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

    // MARK: Step 3 — difficulty

    private var difficultyStep: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            ForEach(DifficultyTier.allCases) { tier in
                DifficultyCard(tier: tier) {
                    selectedDifficulty = tier
                    step = .name
                }
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: Step 4 — party name + code

    private var nameStep: some View {
        VStack(spacing: 20) {
            summaryChips

            StickerTextField(label: "Party Name", text: $partyName,
                             prompt: "Sommer Road Trip")
                .accessibilityIdentifier("party-name-field")

            QuestionCountControl(count: $questionCount)

            VStack(spacing: 8) {
                StickerChip(text: "JOIN CODE", fill: TT.sunshine, textSize: 11)
                HStack(spacing: 14) {
                    JoinCodePlate(code: code)
                    BubbleIconButton(systemName: "dice.fill", fill: TT.bubblegum) {
                        code = String(Int.random(in: 1000...9999))
                    }
                    .accessibilityIdentifier("reroll-code")
                }
            }

            Spacer(minLength: 0)

            Button(action: createParty) {
                RoadSignLabel(title: "Open the Lobby")
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("create-party")
            .opacity(trimmedName.isEmpty ? 0.5 : 1)
            .disabled(trimmedName.isEmpty)
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    private var trimmedName: String {
        partyName.trimmingCharacters(in: .whitespaces)
    }

    private var summaryChips: some View {
        HStack(spacing: 8) {
            StickerChip(text: selectedMode?.displayName.uppercased() ?? "",
                        fill: TT.tangerine, textColor: .white, textSize: 10)
            // Shuffle Genres (Settings) rerolls the genre when the trip
            // actually deals — showing the genre picked here would be
            // misleading about what's actually about to play. Would You
            // Rather always plays its own genre regardless of that setting.
            StickerChip(text: isWouldYouRatherFlow ? selectedGenre?.displayName.uppercased() ?? ""
                        : (app.profile.shuffleGenres ? "SHUFFLED EACH GAME" : selectedGenre?.displayName.uppercased() ?? ""),
                        fill: TT.grape, textColor: .white, textSize: 10)
            StickerChip(text: selectedDifficulty?.displayName.uppercased() ?? "",
                        fill: TT.lime, textColor: .white, textSize: 10)
        }
    }

    private func createParty() {
        guard let mode = selectedMode, let genre = selectedGenre,
              let difficulty = selectedDifficulty, !trimmedName.isEmpty else { return }
        let config = PartyConfig(modeSlug: mode.slug, modeName: mode.displayName,
                                 genreSlug: genre.slug, genreName: genre.displayName,
                                 difficulty: difficulty, minPlayers: mode.minPlayers,
                                 requiresEvenPlayers: mode.requiresEvenPlayers,
                                 questionCount: questionCount)
        app.profile.lastQuestionCount = questionCount
        app.hostParty(partyName: trimmedName, code: code, config: config)
    }
}

// MARK: - Cards

struct ModeCard: View {
    var mode: GameMode
    var select: () -> Void

    private var playerNote: String {
        mode.minPlayers > 2 ? "NEEDS \(mode.minPlayers)+ PLAYERS"
                            : "\(mode.minPlayers)+ PLAYERS"
    }

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.displayName)
                        .font(TT.font(20, .black))
                        .foregroundStyle(TT.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        StickerChip(text: playerNote, fill: TT.sky,
                                    textColor: .white, textSize: 9)
                        if mode.isTeamBased {
                            StickerChip(text: "TEAMS", fill: TT.grape,
                                        textColor: .white, textSize: 9)
                        }
                    }
                }
                Spacer()
                if mode.isPlayable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(TT.ink)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .sticker(RoundedRectangle(cornerRadius: 18),
                     fill: mode.isPlayable ? TT.paper : TT.paper.opacity(0.75))
            .overlay(alignment: .topTrailing) {
                if !mode.isPlayable {
                    StickerChip(text: "COMING SOON", fill: TT.asphalt,
                                textColor: .white, textSize: 9)
                        .rotationEffect(.degrees(6))
                        .offset(x: 4, y: -8)
                }
            }
        }
        .buttonStyle(.bubble)
        .disabled(!mode.isPlayable)
        .saturation(mode.isPlayable ? 1 : 0.15)
        .opacity(mode.isPlayable ? 1 : 0.6)
        .accessibilityIdentifier("mode-\(mode.slug)")
    }
}

struct GenreCard: View {
    var genre: TriviaGenre
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                Image(systemName: genre.contentType == "sound" ? "speaker.wave.2.fill" : "text.book.closed.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(genre.hasContent ? TT.grape : TT.asphalt)
                Text(genre.displayName)
                    .font(TT.font(14, .black))
                    .foregroundStyle(TT.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 104)
            .sticker(RoundedRectangle(cornerRadius: 18),
                     fill: genre.hasContent ? TT.paper : TT.paper.opacity(0.75))
            .overlay(alignment: .topTrailing) {
                if !genre.hasContent {
                    StickerChip(text: "SOON", fill: TT.asphalt,
                                textColor: .white, textSize: 8)
                        .rotationEffect(.degrees(6))
                        .offset(x: 2, y: -6)
                }
            }
        }
        .buttonStyle(.bubble)
        .disabled(!genre.hasContent)
        .saturation(genre.hasContent ? 1 : 0.15)
        .opacity(genre.hasContent ? 1 : 0.6)
        .accessibilityIdentifier("genre-\(genre.slug)")
    }
}

struct DifficultyCard: View {
    var tier: DifficultyTier
    var select: () -> Void

    private var color: Color {
        switch tier {
        case .familyMix: TT.lime
        case .littleOnes: TT.sunshine
        case .grownUp: TT.cherry
        }
    }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                Text(tier.displayName.uppercased())
                    .font(TT.font(22, .black))
                    .foregroundStyle(.white)
                Text(tier.blurb)
                    .font(TT.font(13, .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .sticker(RoundedRectangle(cornerRadius: 20), fill: color)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("difficulty-\(tier.rawValue)")
    }
}

/// The shareable 4-digit code, stamped like a license plate.
struct JoinCodePlate: View {
    var code: String
    var compact: Bool = false

    var body: some View {
        Text(code.map(String.init).joined(separator: " "))
            .font(TT.font(compact ? 26 : 40, .black))
            .monospacedDigit()
            .foregroundStyle(TT.ink)
            .padding(.horizontal, compact ? 14 : 22)
            .padding(.vertical, compact ? 4 : 10)
            .sticker(RoundedRectangle(cornerRadius: compact ? 10 : 14), fill: TT.paper)
            .overlay(alignment: .top) {
                HStack {
                    bolt
                    Spacer()
                    bolt
                }
                .padding(.horizontal, compact ? 5 : 8)
                .padding(.top, compact ? 3 : 5)
            }
    }

    private var bolt: some View {
        Circle()
            .fill(TT.asphalt)
            .overlay(Circle().stroke(TT.ink, lineWidth: 1.2))
            .frame(width: compact ? 5 : 7, height: compact ? 5 : 7)
    }
}
