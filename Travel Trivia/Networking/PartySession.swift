//
//  PartySession.swift
//  Travel Trivia
//
//  The real device-to-device party over Multipeer Connectivity.
//
//  Topology: the host advertises `_travel-trivia._tcp` with the party name,
//  code, and an epoch in its discovery info; joiners browse, pre-validate
//  name+code locally (so a wrong code fails fast with a clear message), and
//  invite the host with a JoinRequest context the host re-validates.
//
//  Authority: the host owns the one true PartyState. Clients only ever send
//  intents; every mutation ends in a full-state broadcast. Because any
//  device can rebuild the whole party from the last snapshot, reconnection
//  and host migration fall out of the same mechanism.
//
//  Dropouts: a vanished peer gets a grace window (seat dims, score freezes,
//  the round keeps moving without them). Reconnecting inside the window
//  reclaims seat + score via the stable playerID; expiring marks them as
//  having left (still shown in results). If the *host* vanishes, the
//  designated backup host promotes itself over the surviving mesh, bumps
//  the epoch, and re-advertises so the dropped host can rejoin as a client.
//

import Foundation
import Observation
@preconcurrency import MultipeerConnectivity

/// Multipeer types cross from delegate queues onto the main actor; they are
/// reference types we only touch on the main actor after the hop.
private nonisolated struct Box<T>: @unchecked Sendable {
    let value: T
}

@Observable
@MainActor
final class PartySession: NSObject {

    enum JoinFailure: Equatable {
        case notFound        // nothing advertising that name+code nearby
        case lost            // connection lost and the grace window expired
    }

    enum Status: Equatable {
        case idle
        case hosting
        case searching       // browsing for the party
        case connecting      // found it, invitation in flight
        case connected       // client with live state
        case reconnecting    // dropped mid-party, trying to get back in
        case failed(JoinFailure)
    }

    private(set) var status: Status = .idle
    private(set) var state: PartyState?

    var isHost: Bool { status == .hosting }
    var localPlayerID: UUID?

    /// Fired on every authoritative state change (host mutation or received
    /// broadcast) — the app wires this into the render layer.
    var onStateChanged: ((PartyState) -> Void)?
    /// The party is over (host ended it, or we're out past the grace
    /// window) — the app routes back to the menu with this message.
    var onPartyClosed: ((String) -> Void)?
    /// Supplied by the app: deals the question deck for a game start,
    /// applying the difficulty tier and the Shuffle Genres setting.
    var dealDeck: ((PartyConfig) -> (deck: [TriviaQuestion], genreSlug: String, genreName: String))?

    // Injectable timings (collapsed in tests).
    var revealDuration: Duration = .seconds(1.9)
    var nobodyConnectedDelay: Duration = .seconds(1.1)
    var curveballPreviewDuration: Duration = CopilotsCurveball.previewDuration
    var wagerDuration: Duration = DoubleOrNothing.wagerWindow
    var disconnectGrace: Duration = PartyWire.disconnectGrace
    var joinTimeout: Duration = .seconds(12)
    /// Heartbeat cadence and how long silence counts as a dropout.
    var heartbeatInterval: Duration = .seconds(4)
    var presenceTimeout: TimeInterval = 11

    // MARK: - Multipeer internals

    @ObservationIgnored private var myPeerID: MCPeerID?
    @ObservationIgnored private var mcSession: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// The peer we currently believe is the host (client side).
    @ObservationIgnored private var hostPeer: MCPeerID?
    /// Host side: live peer → stable player id.
    @ObservationIgnored private var peerPlayers: [MCPeerID: UUID] = [:]
    /// Host side: accepted invitations waiting on their session connect.
    @ObservationIgnored private var pendingJoins: [MCPeerID: JoinRequest] = [:]
    /// Join flow: what we're looking for, kept for rejoin attempts.
    @ObservationIgnored private var joinTarget: (name: String, code: String)?
    @ObservationIgnored private var invitedPeers: Set<MCPeerID> = []
    @ObservationIgnored private var bestEpochSeen = -1
    @ObservationIgnored private var localName = "Player"

    // Host round state
    @ObservationIgnored private var pendingAnswers: [UUID: String] = [:]
    @ObservationIgnored private var graceTasks: [UUID: Task<Void, Never>] = [:]
    @ObservationIgnored private var advanceTask: Task<Void, Never>?
    @ObservationIgnored private var curveballTask: Task<Void, Never>?
    @ObservationIgnored private var wagerTask: Task<Void, Never>?
    @ObservationIgnored private var joinTimeoutTask: Task<Void, Never>?
    @ObservationIgnored private var rejoinTask: Task<Void, Never>?

    // Application-level presence (MC's own dead-peer detection is too slow).
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var lastSeen: [UUID: Date] = [:]     // host side
    @ObservationIgnored private var lastHostContact = Date.distantPast

    // MARK: - Hosting

    func host(partyName: String, code: String, config: PartyConfig,
              playerID: UUID, playerName: String) {
        teardown(keepingState: false)
        localPlayerID = playerID
        localName = playerName

        let hostPlayer = PartyPlayerState(id: playerID, name: playerName, colorIndex: 0)
        var initial = PartyState(partyName: partyName, code: code,
                                 hostID: playerID, config: config)
        initial.players = [hostPlayer]

        makeSession(displayName: playerName, playerID: playerID)
        status = .hosting
        commit(initial)
        #if DEBUG
        guard !suppressesNetworking else { return }
        #endif
        startAdvertising()
        // Also browse while hosting so a partitioned-but-alive host can spot
        // a promoted backup's higher-epoch ad of the *same* party and
        // concede, instead of two hosts advertising forever (see
        // handleFoundPeerAsHost).
        startBrowsing()
        startHeartbeat()
    }

    private func startAdvertising() {
        guard let state, let myPeerID else { return }
        advertiser?.stopAdvertisingPeer()
        let info = ["name": state.partyName.lowercased(),
                    "code": state.code,
                    "epoch": String(state.epoch)]
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                                   discoveryInfo: info,
                                                   serviceType: PartyWire.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    /// Host closes the party on purpose — everyone goes home, no migration.
    func endParty() {
        if let mcSession, !mcSession.connectedPeers.isEmpty {
            try? mcSession.send(WireMessage.partyEnded.encoded(),
                                toPeers: mcSession.connectedPeers, with: .reliable)
        }
        teardown(keepingState: false)
    }

    // MARK: - Joining

    func join(partyName: String, code: String, playerID: UUID, playerName: String) {
        teardown(keepingState: false)
        localPlayerID = playerID
        localName = playerName
        joinTarget = (partyName, code)
        makeSession(displayName: playerName, playerID: playerID)
        status = .searching
        startBrowsing()
        lastHostContact = Date()   // fresh slate for the presence clock
        startHeartbeat()

        let timeout = joinTimeout
        joinTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard let self, !Task.isCancelled else { return }
            if self.status == .searching || self.status == .connecting {
                self.stopBrowsing()
                self.mcSession?.disconnect()
                self.status = .failed(.notFound)
            }
        }
    }

    /// Client leaves on purpose (host uses endParty instead).
    func leaveParty() {
        if let localPlayerID, let hostPeer, mcSession?.connectedPeers.contains(hostPeer) == true {
            send(.intent(.goodbye(playerID: localPlayerID)), to: [hostPeer])
        }
        teardown(keepingState: false)
    }

    /// Manual retry from the join screen after a failure.
    func retryJoin() {
        guard let joinTarget, let localPlayerID else { return }
        join(partyName: joinTarget.name, code: joinTarget.code,
             playerID: localPlayerID, playerName: localName)
    }

    private func startBrowsing() {
        guard let myPeerID else { return }
        browser?.stopBrowsingForPeers()
        invitedPeers = []
        bestEpochSeen = -1
        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: PartyWire.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    // MARK: - Local player actions (host mutates, client sends intents)

    func claimSeat(_ seatIndex: Int) {
        guard let localPlayerID else { return }
        if isHost {
            applyIntent(.requestSeat(playerID: localPlayerID, seatIndex: seatIndex))
        } else if let hostPeer {
            send(.intent(.requestSeat(playerID: localPlayerID, seatIndex: seatIndex)), to: [hostPeer])
        }
    }

    func submitLocalAnswer(optionID: String) {
        guard let localPlayerID else { return }
        if isHost {
            applyIntent(.submitAnswer(playerID: localPlayerID, optionID: optionID))
        } else if let hostPeer {
            send(.intent(.submitAnswer(playerID: localPlayerID, optionID: optionID)), to: [hostPeer])
        }
    }

    /// Double or Nothing: lock in a wager while the current bonus question's
    /// window is open.
    func submitLocalWager(amount: Int) {
        guard let localPlayerID else { return }
        if isHost {
            applyIntent(.submitWager(playerID: localPlayerID, amount: amount))
        } else if let hostPeer {
            send(.intent(.submitWager(playerID: localPlayerID, amount: amount)), to: [hostPeer])
        }
    }

    // MARK: - Host-only party controls

    /// Cycle/assign the pilot & copilot roles from the lobby. Roles are
    /// unique: giving one to a player takes it from whoever had it.
    func assignRole(_ role: PartyRole, to playerID: UUID) {
        guard isHost else { return }
        mutateState { s in
            for i in s.players.indices {
                if s.players[i].id == playerID {
                    s.players[i].role = role
                } else if role != .none, s.players[i].role == role {
                    s.players[i].role = .none
                }
            }
        }
    }

    /// Team Relay: assign (or clear, passing nil) a rider's squad from the
    /// lobby. Unlike pilot/copilot, teams aren't mutually exclusive slots —
    /// the toggle-off decision is made by the caller.
    func assignTeam(_ team: Int?, to playerID: UUID) {
        guard isHost else { return }
        mutateState { s in
            guard let i = s.players.firstIndex(where: { $0.id == playerID }) else { return }
            s.players[i].teamIndex = team
        }
    }

    /// Lobby → Our Ride seat picking.
    func startRide() {
        guard isHost else { return }
        mutateState { $0.phase = .ride }
    }

    /// Our Ride → dealing the deck and playing. Unseated riders get
    /// auto-dropped into free seats so nobody starts seatless.
    func startTrip() {
        guard isHost, var s = state, let dealDeck else { return }
        advanceTask?.cancel()
        curveballTask?.cancel()
        wagerTask?.cancel()
        pendingAnswers = [:]

        var takenSeats = Set(s.players.compactMap(\.seatIndex))
        for i in s.players.indices {
            if s.players[i].presence != .left, s.players[i].seatIndex == nil {
                if let free = (0..<PartyWire.maxPlayers).first(where: { !takenSeats.contains($0) }) {
                    s.players[i].seatIndex = free
                    takenSeats.insert(free)
                }
            }
            s.players[i].score = 0
            s.players[i].strikes = 0
            s.players[i].lastAnswerCorrect = nil
            s.players[i].pendingWager = nil
        }

        let dealt = dealDeck(s.config)
        s.round = RoundState(questions: dealt.deck,
                             genreSlug: dealt.genreSlug,
                             genreName: dealt.genreName)
        s.phase = .playing
        if s.config.modeSlug == TeamRelay.modeSlug {
            initializeTeamRelayTurns(&s)
        }
        commit(s)
        holdIfNobodyCanAnswer()
    }

    /// Team Relay: seat the first connected teammate (by seat order) of each
    /// squad into the relay turn.
    private func initializeTeamRelayTurns(_ s: inout PartyState) {
        for team in 0...1 {
            let members = s.players
                .filter { $0.teamIndex == team && $0.presence == .connected }
                .sorted { ($0.seatIndex ?? .max) < ($1.seatIndex ?? .max) }
            s.round?.teamTurnPlayerID[team] = members.first?.id
        }
    }

    /// Team Relay: rotate each squad's turn to the next connected teammate
    /// in seat order, wrapping around.
    private func advanceTeamRelayTurns(_ s: inout PartyState) {
        guard s.config.modeSlug == TeamRelay.modeSlug else { return }
        for team in 0...1 {
            let members = s.players
                .filter { $0.teamIndex == team && $0.presence == .connected }
                .sorted { ($0.seatIndex ?? .max) < ($1.seatIndex ?? .max) }
            guard !members.isEmpty else {
                s.round?.teamTurnPlayerID[team] = nil
                continue
            }
            if let current = s.round?.teamTurnPlayerID[team],
               let index = members.firstIndex(where: { $0.id == current }) {
                s.round?.teamTurnPlayerID[team] = members[(index + 1) % members.count].id
            } else {
                s.round?.teamTurnPlayerID[team] = members.first?.id
            }
        }
    }

    /// Victory screen → back to the seat picker for another game.
    func returnToRide() {
        guard isHost else { return }
        advanceTask?.cancel()
        curveballTask?.cancel()
        wagerTask?.cancel()
        pendingAnswers = [:]
        mutateState { s in
            s.round = nil
            s.phase = .ride
            for i in s.players.indices {
                s.players[i].lastAnswerCorrect = nil
            }
        }
    }

    // MARK: - Host authority: intents

    private func applyIntent(_ intent: ClientIntent) {
        guard isHost else { return }
        switch intent {
        case .hello(let playerID, _), .requestSeat(let playerID, _),
             .submitAnswer(let playerID, _), .submitWager(let playerID, _),
             .goodbye(let playerID):
            markSeen(playerID)
        }
        switch intent {
        case .hello(let playerID, let name):
            admit(playerID: playerID, name: name, peer: nil)

        case .requestSeat(let playerID, let seatIndex):
            guard (0..<PartyWire.maxPlayers).contains(seatIndex) else { return }
            mutateState { s in
                let seatTaken = s.players.contains {
                    $0.seatIndex == seatIndex && $0.presence != .left && $0.id != playerID
                }
                guard !seatTaken, let i = s.players.firstIndex(where: { $0.id == playerID }) else { return }
                s.players[i].seatIndex = seatIndex
            }

        case .submitAnswer(let playerID, let optionID):
            recordAnswer(playerID: playerID, optionID: optionID)

        case .submitWager(let playerID, let amount):
            recordWager(playerID: playerID, amount: amount)

        case .goodbye(let playerID):
            graceTasks[playerID]?.cancel()
            graceTasks[playerID] = nil
            mutateState { s in
                guard let i = s.players.firstIndex(where: { $0.id == playerID }) else { return }
                if s.phase == .lobby {
                    s.players.remove(at: i)     // clean exit before the game
                } else {
                    s.players[i].presence = .left
                    s.players[i].seatIndex = nil
                }
            }
            reevaluateRoundAfterPresenceChange()
        }
    }

    /// New joiner or reconnecting player. `peer` is non-nil when this came
    /// through an accepted invitation (fresh connection) and nil when it
    /// arrived as a hello intent over a surviving mesh link.
    private func admit(playerID: UUID, name: String, peer: MCPeerID?) {
        markSeen(playerID)
        graceTasks[playerID]?.cancel()
        graceTasks[playerID] = nil
        // A reconnect arrives on a fresh peer while the pre-drop zombie peer
        // may still look connected — retire any stale mapping so the
        // zombie's eventual disconnect can't re-drop the reclaimed player.
        peerPlayers = peerPlayers.filter { $0.value != playerID }
        mutateState { s in
            if let i = s.players.firstIndex(where: { $0.id == playerID }) {
                s.players[i].presence = .connected
                s.players[i].name = name
            } else {
                let activeCount = s.players.count { $0.presence != .left }
                guard activeCount < PartyWire.maxPlayers else { return }
                let usedColors = Set(s.players.map(\.colorIndex))
                let color = (0..<TTAvatarColorCount).first { !usedColors.contains($0) } ?? 0
                s.players.append(PartyPlayerState(id: playerID, name: name, colorIndex: color))
            }
            if s.backupHostID == nil || s.backupHostID == s.hostID {
                s.backupHostID = s.players.first {
                    $0.id != s.hostID && $0.presence == .connected
                }?.id
            }
        }
        if let peer {
            peerPlayers[peer] = playerID
        }
        reevaluateRoundAfterPresenceChange()
    }

    private func playerDropped(peer: MCPeerID) {
        guard let playerID = peerPlayers[peer] else { return }
        peerPlayers[peer] = nil
        dropPlayer(playerID)
    }

    /// A player went silent (socket died or heartbeats stopped): start
    /// their grace window.
    private func dropPlayer(_ playerID: UUID) {
        guard state?.player(playerID)?.presence == .connected else { return }

        mutateState { s in
            guard let i = s.players.firstIndex(where: { $0.id == playerID }) else { return }
            s.players[i].presence = .dropped
            if s.backupHostID == playerID {
                s.backupHostID = s.players.first {
                    $0.id != s.hostID && $0.id != playerID && $0.presence == .connected
                }?.id
            }
        }
        pendingAnswers[playerID] = nil
        reevaluateRoundAfterPresenceChange()

        let grace = disconnectGrace
        graceTasks[playerID] = Task { [weak self] in
            try? await Task.sleep(for: grace)
            guard let self, !Task.isCancelled else { return }
            self.graceExpired(for: playerID)
        }
    }

    private func graceExpired(for playerID: UUID) {
        graceTasks[playerID] = nil
        guard state?.player(playerID)?.presence == .dropped else { return }
        mutateState { s in
            guard let i = s.players.firstIndex(where: { $0.id == playerID }) else { return }
            s.players[i].presence = .left
            s.players[i].seatIndex = nil
        }
        reevaluateRoundAfterPresenceChange()
    }

    // MARK: - Host authority: round logic

    /// Players the current question waits on: connected and still in it.
    /// Team Relay narrows this to just the two riders whose relay turn it
    /// is — everyone else's tap is a no-op (recordAnswer rejects it below).
    private var answerGate: [UUID] {
        guard let s = state, s.phase == .playing, let round = s.round,
              !round.revealing, !round.curveballPreview, !round.wagerOpen else { return [] }
        if s.config.modeSlug == TeamRelay.modeSlug {
            return round.teamTurnPlayerID.compactMap { $0 }.filter { id in
                s.player(id)?.presence == .connected
            }
        }
        let threshold = Elimination.maxStrikes(modeSlug: s.config.modeSlug)
        return s.players
            .filter { $0.presence == .connected && $0.strikes < threshold }
            .map(\.id)
    }

    private func recordAnswer(playerID: UUID, optionID: String) {
        guard let s = state, s.phase == .playing, let round = s.round,
              !round.revealing, !round.curveballPreview, !round.wagerOpen,
              round.questions.indices.contains(round.questionIndex),
              pendingAnswers[playerID] == nil,
              answerGate.contains(playerID),
              round.questions[round.questionIndex].options.contains(where: { $0.id == optionID })
        else { return }
        pendingAnswers[playerID] = optionID
        resolveIfEveryoneAnswered()
    }

    /// Double or Nothing: lock in a wager while the bonus question's window
    /// is open. Clamped to what the player can actually afford.
    private func recordWager(playerID: UUID, amount: Int) {
        guard let s = state, s.phase == .playing, s.round?.wagerOpen == true,
              let player = s.player(playerID), player.presence == .connected
        else { return }
        let clamped = max(0, min(amount, player.score))
        mutateState { st in
            guard let i = st.players.firstIndex(where: { $0.id == playerID }) else { return }
            st.players[i].pendingWager = clamped
        }
    }

    private func resolveIfEveryoneAnswered() {
        let gate = answerGate
        guard !gate.isEmpty, gate.allSatisfy({ pendingAnswers[$0] != nil }) else { return }
        resolveQuestion()
    }

    private func resolveQuestion() {
        guard var s = state, let round = s.round,
              round.questions.indices.contains(round.questionIndex) else { return }
        let question = round.questions[round.questionIndex]

        // Authored questions grade against their fixed answer; prediction
        // questions (Would You Rather) grade against whichever option won
        // the car's vote — and Herd Reveal forces that same majority path
        // even when the question does have an authored answer, since the
        // whole point of the mode is scoring popularity, not correctness.
        let correctID: String?
        if s.config.modeSlug == HerdReveal.modeSlug {
            correctID = MajorityVote.winningOptionID(votes: pendingAnswers.values, options: question.options)
        } else {
            correctID = question.correctOptionID
                ?? MajorityVote.winningOptionID(votes: pendingAnswers.values, options: question.options)
        }

        // Double or Nothing: every Nth question settles against the
        // player's wager instead of the flat +1/strike — correct doubles
        // it (net +wager), wrong subtracts it, floored at zero. No strike:
        // wagering isn't an elimination risk.
        let isWagerQuestion = s.config.modeSlug == DoubleOrNothing.modeSlug
            && DoubleOrNothing.isWagerIndex(round.questionIndex)

        for i in s.players.indices {
            guard let answer = pendingAnswers[s.players[i].id] else { continue }
            let correct = answer == correctID
            s.players[i].lastAnswerCorrect = correct
            if isWagerQuestion {
                let wager = s.players[i].pendingWager ?? 0
                s.players[i].score = correct ? s.players[i].score + wager
                                              : max(0, s.players[i].score - wager)
                s.players[i].pendingWager = nil
            } else if correct {
                s.players[i].score += 1
            } else {
                s.players[i].strikes += 1
            }
        }
        pendingAnswers = [:]
        s.round?.revealing = true
        s.round?.resolvedCorrectOptionID = correctID
        commit(s)
        scheduleAdvance(after: revealDuration)
    }

    private func scheduleAdvance(after delay: Duration) {
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            self.advance()
        }
    }

    private func advance() {
        guard var s = state, s.phase == .playing, let round = s.round else { return }
        for i in s.players.indices {
            s.players[i].lastAnswerCorrect = nil
        }
        s.round?.revealing = false
        s.round?.resolvedCorrectOptionID = nil

        let threshold = Elimination.maxStrikes(modeSlug: s.config.modeSlug)
        let alive = s.players.filter { $0.strikes < threshold && $0.presence != .left }
        let deckExhausted = round.questionIndex + 1 >= round.questions.count
        if alive.count <= 1 || deckExhausted {
            finishRound(&s)
        } else {
            s.round?.questionIndex = round.questionIndex + 1
            advanceTeamRelayTurns(&s)
            beginCurveballPreviewIfDue(&s)
            beginWagerWindowIfDue(&s)
        }
        commit(s)
        holdIfNobodyCanAnswer()
    }

    // MARK: - Copilot's Curveball

    /// In Copilot's Curveball, every Nth question opens with a short window
    /// where only the copilot's phone shows it — a real-world head start to
    /// verbally help (or mislead) the car before anyone can answer. Needs a
    /// connected copilot to mean anything; otherwise the question plays
    /// normally.
    private func beginCurveballPreviewIfDue(_ s: inout PartyState) {
        guard s.config.modeSlug == CopilotsCurveball.modeSlug,
              let index = s.round?.questionIndex,
              CopilotsCurveball.isCurveballIndex(index),
              s.players.contains(where: { $0.role == .copilot && $0.presence == .connected })
        else { return }
        s.round?.curveballPreview = true
        scheduleCurveballEnd()
    }

    private func scheduleCurveballEnd() {
        curveballTask?.cancel()
        let window = curveballPreviewDuration
        curveballTask = Task { [weak self] in
            try? await Task.sleep(for: window)
            guard let self, !Task.isCancelled else { return }
            self.endCurveballPreview()
        }
    }

    private func endCurveballPreview() {
        guard state?.round?.curveballPreview == true else { return }
        mutateState { $0.round?.curveballPreview = false }
        // The gate just opened; if nobody connected can answer, keep moving.
        holdIfNobodyCanAnswer()
    }

    // MARK: - Double or Nothing

    /// Every Nth question opens with a window where players lock in a
    /// wager against their current score before the question is answerable
    /// — mirrors Copilot's Curveball's fixed preview window (no early
    /// close on "everyone's wagered" to keep the mechanic simple).
    private func beginWagerWindowIfDue(_ s: inout PartyState) {
        guard s.config.modeSlug == DoubleOrNothing.modeSlug,
              let index = s.round?.questionIndex,
              DoubleOrNothing.isWagerIndex(index)
        else { return }
        s.round?.wagerOpen = true
        scheduleWagerEnd()
    }

    private func scheduleWagerEnd() {
        wagerTask?.cancel()
        let window = wagerDuration
        wagerTask = Task { [weak self] in
            try? await Task.sleep(for: window)
            guard let self, !Task.isCancelled else { return }
            self.endWagerWindow()
        }
    }

    private func endWagerWindow() {
        guard state?.round?.wagerOpen == true else { return }
        mutateState { $0.round?.wagerOpen = false }
        // The gate just opened; if nobody connected can answer, keep moving.
        holdIfNobodyCanAnswer()
    }

    private func finishRound(_ s: inout PartyState) {
        if s.config.modeSlug == TeamRelay.modeSlug {
            finishTeamRelayRound(&s)
            return
        }
        // Same rules as the practice engine: last one standing, else score,
        // fewer strikes breaks ties, front seat wins dead heats.
        let threshold = Elimination.maxStrikes(modeSlug: s.config.modeSlug)
        let alive = s.players.filter { $0.strikes < threshold && $0.presence != .left }
        let pool = alive.isEmpty ? s.players : alive
        let winner = pool.max { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.strikes != b.strikes { return a.strikes > b.strikes }
            return (a.seatIndex ?? .max) > (b.seatIndex ?? .max)
        }
        s.round?.winnerID = winner?.id
        s.phase = .victory
    }

    /// Team Relay: cumulative squad totals decide it, not individual
    /// standing. `winnerID` still needs a single player (the victory
    /// screen shows one avatar), so it's the winning squad's top scorer —
    /// fewest strikes, then front seat, breaks ties, same as everywhere
    /// else.
    private func finishTeamRelayRound(_ s: inout PartyState) {
        let team0Total = s.players.filter { $0.teamIndex == 0 }.reduce(0) { $0 + $1.score }
        let team1Total = s.players.filter { $0.teamIndex == 1 }.reduce(0) { $0 + $1.score }
        let winningTeam = team1Total > team0Total ? 1 : 0
        let pool = s.players.filter { $0.teamIndex == winningTeam }
        let fallbackPool = pool.isEmpty ? s.players : pool
        let winner = fallbackPool.max { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.strikes != b.strikes { return a.strikes > b.strikes }
            return (a.seatIndex ?? .max) > (b.seatIndex ?? .max)
        }
        s.round?.winnerID = winner?.id
        s.phase = .victory
    }

    /// If literally nobody connected can answer (everyone alive is dropped
    /// or everyone connected is out), the question auto-reveals after a beat
    /// so the round never stalls — mirrors the practice spectator flow.
    private func holdIfNobodyCanAnswer() {
        guard let s = state, s.phase == .playing, let round = s.round,
              !round.revealing, !round.curveballPreview, !round.wagerOpen else { return }
        guard answerGate.isEmpty else { return }
        scheduleAdvance(after: nobodyConnectedDelay)
    }

    /// A presence change can open or close the answer gate mid-question.
    private func reevaluateRoundAfterPresenceChange() {
        guard let s = state, s.phase == .playing else { return }
        if s.round?.revealing == false {
            resolveIfEveryoneAnswered()
            holdIfNobodyCanAnswer()
        }
    }

    // MARK: - Presence heartbeats

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        let interval = heartbeatInterval
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                self.heartbeatTick()
            }
        }
    }

    private func heartbeatTick() {
        if isHost {
            if let mcSession, !mcSession.connectedPeers.isEmpty {
                send(.ping, to: mcSession.connectedPeers)
            }
            // Sweep for silent players well before MCSession notices.
            guard let state, let localPlayerID else { return }
            let cutoff = Date().addingTimeInterval(-presenceTimeout)
            for player in state.players
            where player.presence == .connected && player.id != localPlayerID {
                if let seen = lastSeen[player.id], seen < cutoff {
                    dropPlayer(player.id)
                }
            }
        } else if status == .connected {
            if lastHostContact < Date().addingTimeInterval(-presenceTimeout) {
                hostPresumedLost()
            }
        }
    }

    private func markSeen(_ playerID: UUID) {
        lastSeen[playerID] = Date()
    }

    /// The host went silent past the presence timeout — same handling as an
    /// observed socket loss.
    private func hostPresumedLost() {
        if state?.backupHostID == localPlayerID {
            promoteToHost()
        } else {
            hostPeer = nil
            beginReconnect()
        }
    }

    // MARK: - Host migration

    /// The host vanished and we're the designated backup: take over with the
    /// last known snapshot, bump the epoch, and re-advertise the same party.
    private func promoteToHost() {
        guard var s = state, let localPlayerID else { return }
        let oldHostID = s.hostID
        s.epoch += 1
        s.hostID = localPlayerID
        s.backupHostID = s.players.first {
            $0.id != localPlayerID && $0.id != oldHostID && $0.presence == .connected
        }?.id

        if let i = s.players.firstIndex(where: { $0.id == oldHostID }),
           s.players[i].presence == .connected {
            s.players[i].presence = .dropped
        }

        hostPeer = nil
        peerPlayers = [:]        // rebuilt from hello intents
        pendingAnswers = [:]     // in-flight answers died with the old host
        status = .hosting
        rejoinTask?.cancel()
        // Give every surviving player a fresh presence clock so the sweep
        // can't drop them before their hellos arrive.
        for player in s.players where player.presence == .connected {
            markSeen(player.id)
        }
        commit(s)
        startAdvertising()
        startHeartbeat()

        // The old host gets the same grace window as any dropped player.
        let grace = disconnectGrace
        graceTasks[oldHostID] = Task { [weak self] in
            try? await Task.sleep(for: grace)
            guard let self, !Task.isCancelled else { return }
            self.graceExpired(for: oldHostID)
        }

        // If a reveal was mid-flight when the host died, resume its clock;
        // a curveball preview restarts its window; otherwise players
        // re-answer the current question.
        if s.phase == .playing {
            if s.round?.revealing == true {
                scheduleAdvance(after: revealDuration)
            } else if s.round?.curveballPreview == true {
                scheduleCurveballEnd()
            } else {
                holdIfNobodyCanAnswer()
            }
        }
    }

    /// Client lost its link to the host (or everyone). Wait briefly for a
    /// promoted backup to speak up over the surviving mesh; failing that,
    /// re-browse and rejoin for the rest of the grace window.
    private func beginReconnect() {
        guard status == .connected || status == .reconnecting else { return }
        status = .reconnecting
        guard rejoinTask == nil else { return }

        let grace = disconnectGrace
        rejoinTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, !Task.isCancelled, self.status == .reconnecting else { return }
            self.startBrowsing()   // nobody promoted into our mesh — go look
            try? await Task.sleep(for: grace)
            guard !Task.isCancelled, self.status == .reconnecting else { return }
            self.stopBrowsing()
            self.teardown(keepingState: false)
            self.status = .failed(.lost)
        }
    }

    // MARK: - Incoming (main-actor handlers behind the delegate hops)

    private func handlePeerChanged(_ peerID: MCPeerID, to peerState: MCSessionState) {
        switch peerState {
        case .connected:
            if isHost {
                if let join = pendingJoins.removeValue(forKey: peerID) {
                    admit(playerID: join.playerID, name: join.name, peer: peerID)
                } else {
                    broadcast()   // mesh link came up; make sure they have state
                }
            } else if invitedPeers.contains(peerID) {
                // Our invitation to the host landed — introduce ourselves.
                hostPeer = peerID
                if let localPlayerID {
                    send(.intent(.hello(playerID: localPlayerID, name: localName)), to: [peerID])
                }
            }

        case .notConnected:
            if isHost {
                playerDropped(peer: peerID)
            } else {
                handleLostPeerAsClient(peerID)
            }

        case .connecting:
            break

        @unknown default:
            break
        }
    }

    private func handleLostPeerAsClient(_ peerID: MCPeerID) {
        let lostHost = peerID == hostPeer
        let allGone = mcSession?.connectedPeers.isEmpty ?? true
        guard lostHost || allGone else { return }

        if status == .searching || status == .connecting {
            // Invitation fizzled (host gone or declined a stale ad) — let
            // the join timeout surface not-found; allow later finds to retry.
            invitedPeers.remove(peerID)
            return
        }

        if lostHost, state?.backupHostID == localPlayerID {
            promoteToHost()
        } else {
            if lostHost { hostPeer = nil }
            beginReconnect()
        }
    }

    private func handleIncoming(_ message: WireMessage, from peerID: MCPeerID) {
        switch message {
        case .state(let incoming):
            guard !isHost else { return }
            if let current = state, incoming.epoch < current.epoch { return }
            let hostChanged = state?.hostID != incoming.hostID
            hostPeer = peerID
            lastHostContact = Date()
            joinTimeoutTask?.cancel()
            rejoinTask?.cancel()
            rejoinTask = nil
            stopBrowsing()
            status = .connected
            state = incoming
            onStateChanged?(incoming)
            if hostChanged, let localPlayerID {
                // New host after a migration — rebuild its peer mapping.
                send(.intent(.hello(playerID: localPlayerID, name: localName)), to: [peerID])
            }

        case .intent(let intent):
            if isHost { applyIntent(intent) }

        case .partyEnded:
            guard !isHost else { return }
            teardown(keepingState: false)
            onPartyClosed?("The pilot ended the party")

        case .ping:
            guard !isHost else { return }
            lastHostContact = Date()
            if let localPlayerID {
                send(.pong(playerID: localPlayerID), to: [peerID])
            }

        case .pong(let playerID):
            if isHost { markSeen(playerID) }
        }
    }

    private func handleInvitation(peer: MCPeerID, context: Data?,
                                  handler: @escaping (Bool, MCSession?) -> Void) {
        guard isHost, let state, let mcSession,
              let context, let request = try? JSONDecoder().decode(JoinRequest.self, from: context),
              request.code == state.code
        else {
            handler(false, nil)
            return
        }
        let isReturning = state.player(request.playerID) != nil
        let activeCount = state.players.count { $0.presence != .left }
        guard isReturning || activeCount < PartyWire.maxPlayers else {
            handler(false, nil)
            return
        }
        pendingJoins[peer] = request
        handler(true, mcSession)
    }

    private func handleFoundPeer(_ peerID: MCPeerID, info: [String: String]?) {
        // A partitioned-but-alive host browses too (see `host()`) purely to
        // watch for a promoted backup's higher-epoch ad of its own party —
        // it never invites anyone, joiners' invite flow below doesn't apply.
        if isHost {
            handleFoundPeerAsHost(info: info)
            return
        }

        guard status == .searching || status == .connecting || status == .reconnecting,
              let joinTarget, let info,
              info["name"] == joinTarget.name.lowercased(),
              info["code"] == joinTarget.code,
              let mcSession, let localPlayerID
        else { return }

        let epoch = Int(info["epoch"] ?? "0") ?? 0
        guard epoch >= bestEpochSeen else { return }
        bestEpochSeen = epoch
        guard !invitedPeers.contains(peerID) else { return }
        invitedPeers.insert(peerID)

        let request = JoinRequest(code: joinTarget.code, playerID: localPlayerID, name: localName)
        guard let context = try? JSONEncoder().encode(request) else { return }
        if status == .searching { status = .connecting }
        browser?.invitePeer(peerID, to: mcSession, withContext: context, timeout: 15)
    }

    /// A network partition (or a slow phone) can leave a stale host still
    /// advertising while the mesh has already promoted a backup host over a
    /// higher epoch (see PartySession's file comment + `promoteToHost`).
    /// Joiners already resolve that correctly by picking the highest epoch
    /// they see; this closes the other half — the *stale* host itself spots
    /// the rival ad for its own party+code and concedes rather than
    /// advertising a dead epoch forever.
    private func handleFoundPeerAsHost(info: [String: String]?) {
        guard let state, let info,
              info["name"] == state.partyName.lowercased(),
              info["code"] == state.code,
              let rivalEpoch = Int(info["epoch"] ?? "0"),
              rivalEpoch > state.epoch
        else { return }
        demoteToClient()
    }

    /// Concede to the higher-epoch host: stop advertising, tear down as
    /// host, and try to rejoin the party as an ordinary client.
    private func demoteToClient() {
        guard isHost, let state, let localPlayerID else { return }
        let partyName = state.partyName
        let code = state.code
        let playerName = localName
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        teardown(keepingState: false)
        #if DEBUG
        guard !suppressesNetworking else {
            // Headless test seam: assert the demotion decision itself
            // without opening real Multipeer sockets — see
            // debugSimulateRivalHostAd below.
            self.localPlayerID = localPlayerID
            localName = playerName
            joinTarget = (partyName, code)
            status = .searching
            return
        }
        #endif
        join(partyName: partyName, code: code, playerID: localPlayerID, playerName: playerName)
    }

    // MARK: - Plumbing

    private func makeSession(displayName: String, playerID: UUID) {
        // Peer names must be unique per *launch*, not just per player: a
        // reconnecting phone shows up while the host may still hold its
        // zombie peer from before the drop, and Multipeer misbehaves when
        // two peers share a display name. Identity rides in JoinRequest's
        // stable playerID instead.
        let suffix = UUID().uuidString.prefix(4)
        let peer = MCPeerID(displayName: "\(displayName.prefix(20))•\(suffix)")
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        myPeerID = peer
        mcSession = session
    }

    private func mutateState(_ mutate: (inout PartyState) -> Void) {
        guard var s = state else { return }
        mutate(&s)
        commit(s)
    }

    private func commit(_ s: PartyState) {
        state = s
        onStateChanged?(s)
        broadcast()
    }

    private func broadcast() {
        guard isHost, let state, let mcSession, !mcSession.connectedPeers.isEmpty else { return }
        send(.state(state), to: mcSession.connectedPeers)
    }

    private func send(_ message: WireMessage, to peers: [MCPeerID]) {
        guard let mcSession, !peers.isEmpty else { return }
        do {
            try mcSession.send(message.encoded(), toPeers: peers, with: .reliable)
        } catch {
            // Transient send failures self-heal: every mutation rebroadcasts
            // the full state, and reconnects trigger a fresh push.
        }
    }

    private func teardown(keepingState: Bool) {
        advanceTask?.cancel()
        curveballTask?.cancel()
        wagerTask?.cancel()
        joinTimeoutTask?.cancel()
        rejoinTask?.cancel()
        rejoinTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        lastSeen = [:]
        lastHostContact = .distantPast
        graceTasks.values.forEach { $0.cancel() }
        graceTasks = [:]
        pendingAnswers = [:]
        pendingJoins = [:]
        peerPlayers = [:]
        invitedPeers = []
        bestEpochSeen = -1
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        stopBrowsing()
        mcSession?.disconnect()
        mcSession = nil
        myPeerID = nil
        hostPeer = nil
        if !keepingState {
            state = nil
            status = .idle
        }
    }

    #if DEBUG
    /// Test seams: drive the host's authority logic headlessly (no Multipeer
    /// traffic) by injecting the same intents real clients would send, and
    /// await the host's scheduled round work deterministically.
    var suppressesNetworking = false

    func debugApplyIntent(_ intent: ClientIntent) {
        applyIntent(intent)
    }

    func debugWaitForAdvance() async {
        await advanceTask?.value
    }

    func debugWaitForCurveballWindow() async {
        await curveballTask?.value
    }

    func debugWaitForWagerWindow() async {
        await wagerTask?.value
    }

    /// Headless host-partition test seam: feed the same rival-advertisement
    /// info a real MCNearbyServiceBrowser would hand `handleFoundPeer`,
    /// without opening any real Multipeer sockets. Verifies the *decision*
    /// to demote (see `handleFoundPeerAsHost`/`demoteToClient`) — it does
    /// not exercise the real rejoin-over-the-mesh path, which needs an
    /// actual network partition to test for real.
    func debugSimulateRivalHostAd(epoch: Int, name: String? = nil, code: String? = nil) {
        guard let state else { return }
        let info = ["name": (name ?? state.partyName).lowercased(),
                    "code": code ?? state.code,
                    "epoch": String(epoch)]
        handleFoundPeerAsHost(info: info)
    }
    #endif
}

/// Matches TT.avatarColors.count without importing SwiftUI here.
private let TTAvatarColorCount = 6

// MARK: - Multipeer delegates (background queues → main actor hops)

extension PartySession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                             didChange state: MCSessionState) {
        let box = Box(value: peerID)
        Task { @MainActor in
            self.handlePeerChanged(box.value, to: state)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data,
                             fromPeer peerID: MCPeerID) {
        guard let message = try? WireMessage.decoded(from: data) else { return }
        let box = Box(value: peerID)
        Task { @MainActor in
            self.handleIncoming(message, from: box.value)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}

extension PartySession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let peerBox = Box(value: peerID)
        let handlerBox = Box(value: invitationHandler)
        Task { @MainActor in
            self.handleInvitation(peer: peerBox.value, context: context,
                                  handler: handlerBox.value)
        }
    }
}

extension PartySession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let box = Box(value: peerID)
        Task { @MainActor in
            self.handleFoundPeer(box.value, info: info)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
