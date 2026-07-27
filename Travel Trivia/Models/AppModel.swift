//
//  AppModel.swift
//  Travel Trivia
//
//  Top-level navigation + the glue between the party session, the render
//  engine, the local profile, and the content catalog.
//

import Foundation
import Observation

@Observable
@MainActor
final class AppModel {

    enum Route: Equatable {
        /// One-time first-launch sign-in offer, shown before Main Menu ever
        /// appears — see `LocalProfile.hasSeenWelcomeSignInPrompt`.
        case welcomeSignIn
        case menu
        case createGame
        case joinGame
        case settings
        /// My Garage: avatar/car customization shop plus the badges tab.
        case garage
        /// Live party: lobby → ride → playing → victory, driven by the
        /// synced party phase.
        case party
        /// The session-1 single-device slice, kept for debug/screenshot runs.
        case practice
    }

    var route: Route
    /// One-line banner shown on the menu after a party closes under us.
    var partyClosedMessage: String?

    let profile: LocalProfile
    let catalog: ContentCatalog
    let party: PartySession
    let engine: GameEngine
    let audio: AudioDirector
    let progress: ProgressStore
    /// Host-only authentication (Apple / Google via Supabase Auth). Joining
    /// players never touch this — see PartySession's join flow.
    let auth: AuthManager

    init(engine: GameEngine, profile: LocalProfile = LocalProfile(),
         catalog: ContentCatalog = ContentCatalog(), party: PartySession = PartySession(),
         progress: ProgressStore, auth: AuthManager = AuthManager()) {
        self.engine = engine
        self.profile = profile
        self.catalog = catalog
        self.party = party
        self.progress = progress
        self.auth = auth
        self.audio = AudioDirector(profile: profile)
        audio.configureSession()
        engine.progress = progress
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-TTSkipWelcome") {
            profile.hasSeenWelcomeSignInPrompt = true
        } else if arguments.contains("-TTShowWelcome") {
            profile.hasSeenWelcomeSignInPrompt = false
        }
        #endif
        route = profile.hasSeenWelcomeSignInPrompt ? .menu : .welcomeSignIn
        wireParty()
    }

    /// Skip tapped, or a sign-in attempt (successful or not) resolved —
    /// either way the one-time prompt is done; permanent, never shown again.
    func dismissWelcomeSignInPrompt() {
        profile.hasSeenWelcomeSignInPrompt = true
        if route == .welcomeSignIn {
            route = .menu
        }
    }

    private func wireParty() {
        party.onStateChanged = { [weak self] state in
            guard let self else { return }
            engine.applyPartyState(state)
            if route == .joinGame || route == .createGame {
                route = .party
            }
        }
        party.onPartyClosed = { [weak self] message in
            guard let self else { return }
            engine.detachParty()
            partyClosedMessage = message
            route = .menu
        }
        party.dealDeck = { [weak self] config in
            let genre: (slug: String, name: String)
            if let self, profile.shuffleGenres,
               let rolled = catalog.contentReadyGenres.randomElement() {
                genre = (rolled.slug, rolled.displayName)
            } else {
                genre = (config.genreSlug, config.genreName)
            }
            let deck = QuestionDeck.deal(genreSlug: genre.slug, tier: config.difficulty,
                                         livePack: self?.catalog.questionPack(genreSlug: genre.slug))
            return (deck, genre.slug, genre.name)
        }
    }

    // MARK: - Party lifecycle

    func hostParty(partyName: String, code: String, config: PartyConfig) {
        engine.attachParty(party, localPlayerID: profile.playerID)
        party.host(partyName: partyName, code: code, config: config,
                   playerID: profile.playerID, playerName: profile.displayName)
        route = .party
    }

    func joinParty(partyName: String, code: String) {
        engine.attachParty(party, localPlayerID: profile.playerID)
        party.join(partyName: partyName, code: code,
                   playerID: profile.playerID, playerName: profile.displayName)
        // Stays on the join screen until the first synced state flips us over.
    }

    /// Local player backs out (host: ends the party for everyone). Used
    /// from the Lobby, before anyone's invested in a round.
    func leaveParty() {
        if party.isHost {
            party.endParty()
        } else {
            party.leaveParty()
        }
        engine.detachParty()
        route = .menu
    }

    /// Any player leaves a game already in progress (the mid-game
    /// scoreboard's Leave Game button) — unlike `leaveParty()`, the rest of
    /// the car keeps playing: a departing host hands off to the backup
    /// instead of ending the party, and a departing non-host is marked
    /// gone immediately rather than going through the accidental-dropout
    /// grace window.
    func leaveGameInProgress() {
        party.leaveGameInProgress()
        engine.detachParty()
        route = .menu
    }

    // MARK: - Debug drive-throughs

    #if DEBUG
    @ObservationIgnored private var autoFlowTask: Task<Void, Never>?
    @ObservationIgnored private var autoFlowLingerTicks = 0

    /// -TTPractice / -TTAutoStart / -TTVictory land in the session-1 slice;
    /// -TTHostParty <name> <code> [player] and -TTJoinParty <name> <code>
    /// [player] drive real Multipeer flows for two-simulator testing.
    /// -TTAutoFlow makes the device play itself (host advances phases,
    /// everyone claims seats and answers); -TTShortGrace shrinks the
    /// disconnect grace window to 10 s so dropout tests don't wait 45.
    func debugApplyLaunchArguments(_ arguments: [String]) {
        if arguments.contains("-TTResetProgress") {
            progress.debugResetAll()
        }
        // -TTGrantCoins <n>: deterministic coin balance for shop UI tests,
        // rather than depending on a scripted win's exact payout.
        if let i = arguments.firstIndex(of: "-TTGrantCoins"), arguments.count > i + 1,
           let amount = Int(arguments[i + 1]) {
            progress.awardCoins(amount)
        }
        if arguments.contains("-TTSettings") {
            route = .settings
        }
        if arguments.contains("-TTPractice") || arguments.contains("-TTAutoStart")
            || arguments.contains("-TTVictory") {
            route = .practice
            engine.debugApplyLaunchArguments(arguments)
            return
        }
        if arguments.contains("-TTShortGrace") {
            party.disconnectGrace = .seconds(10)
        }
        if let i = arguments.firstIndex(of: "-TTHostParty"), arguments.count > i + 2 {
            profile.displayName = arguments.count > i + 3 ? arguments[i + 3] : "Pilot"
            // -TTMode <slug> / -TTGenre <slug> pick the game; defaults match
            // the session-2 harness.
            func value(after flag: String) -> String? {
                guard let f = arguments.firstIndex(of: flag), arguments.count > f + 1 else { return nil }
                return arguments[f + 1]
            }
            let mode = catalog.mode(slug: value(after: "-TTMode") ?? "three-strikes")
                ?? ContentCatalog.bundledModes.last!
            let genre = catalog.genre(slug: value(after: "-TTGenre") ?? "riddle-realm")
                ?? ContentCatalog.bundledGenres.first { $0.slug == "riddle-realm" }!
            let config = PartyConfig(modeSlug: mode.slug, modeName: mode.displayName,
                                     genreSlug: genre.slug, genreName: genre.displayName,
                                     difficulty: .familyMix, minPlayers: 2,
                                     requiresEvenPlayers: mode.requiresEvenPlayers)
            hostParty(partyName: arguments[i + 1], code: arguments[i + 2], config: config)
        }
        if let i = arguments.firstIndex(of: "-TTJoinParty"), arguments.count > i + 2 {
            if arguments.count > i + 3 {
                profile.displayName = arguments[i + 3]
            }
            route = .joinGame
            joinParty(partyName: arguments[i + 1], code: arguments[i + 2])
        }
        if arguments.contains("-TTAutoFlow") {
            beginAutoFlow()
        }
    }

    private func beginAutoFlow() {
        autoFlowTask?.cancel()
        autoFlowTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard let self else { return }
                self.autoFlowTick()
            }
        }
    }

    private func autoFlowTick() {
        // Self-heal the harness: a failed join keeps retrying.
        if case .failed = party.status {
            party.retryJoin()
            return
        }
        guard let state = party.state else { return }
        let myID = profile.playerID
        switch state.phase {
        case .lobby:
            guard party.isHost, state.connectedCount >= 2 else { return }
            // Sync check: host takes pilot, hands copilot to the first rider.
            if state.player(myID)?.role == .none {
                party.assignRole(.pilot, to: myID)
            }
            if let rider = state.players.first(where: { $0.id != myID && $0.presence == .connected }),
               rider.role == .none {
                party.assignRole(.copilot, to: rider.id)
            }
            // Team Relay needs every connected rider on a squad before it
            // can start meaningfully (see PartyState.everyConnectedPlayerHasATeam)
            // — split them alternately across the two squads by join order.
            if state.config.modeSlug == TeamRelay.modeSlug {
                for (index, player) in state.players.filter({ $0.presence == .connected }).enumerated()
                where player.teamIndex == nil {
                    party.assignTeam(index % 2, to: player.id)
                }
            }
            autoFlowLingerTicks += 1     // linger a beat for screenshots
            if autoFlowLingerTicks >= 3 {
                autoFlowLingerTicks = 0
                party.startRide()
            }
        case .ride:
            if state.player(myID)?.seatIndex == nil {
                let taken = Set(state.players.compactMap(\.seatIndex))
                if let free = (0..<PartyWire.maxPlayers).first(where: { !taken.contains($0) }) {
                    party.claimSeat(free)
                }
            } else if party.isHost {
                let connected = state.players.filter { $0.presence == .connected }
                guard connected.count >= 2, connected.allSatisfy({ $0.seatIndex != nil }) else { return }
                autoFlowLingerTicks += 1
                if autoFlowLingerTicks >= 2 {
                    autoFlowLingerTicks = 0
                    party.startTrip()
                }
            }
        case .playing:
            if engine.turnState == .awaitingAnswer, engine.userPickedOptionID == nil,
               let question = engine.currentQuestion,
               let me = state.player(myID), me.presence == .connected,
               me.strikes < Elimination.maxStrikes(modeSlug: state.config.modeSlug) {
                // Prediction questions have no authored answer: each player
                // votes one of the first two options, keyed off its stable
                // playerID, so a 3+ player run produces a real plurality.
                let pick = question.correctOptionID
                    ?? question.options[myID.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 2 }].id
                engine.submitUserAnswer(optionID: pick)
            }
        case .victory:
            break
        }
    }
    #endif
}
