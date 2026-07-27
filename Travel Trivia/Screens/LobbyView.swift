//
//  LobbyView.swift
//  Travel Trivia
//
//  The party staging area between game setup and Our Ride. Shows the
//  shareable name + join code, the live roster from real Multipeer
//  connections, the game summary, and pilot/copilot role assignment
//  (host-only — decided fresh here every trip, since who's driving
//  changes trip to trip).
//

import SwiftUI

struct LobbyView: View {
    @Environment(AppModel.self) private var app

    @State private var confirmLeave = false
    @State private var confirmShortStart = false

    private var state: PartyState? { app.party.state }
    private var isHost: Bool { app.party.isHost }
    private var isTeamRelay: Bool { state?.config.modeSlug == TeamRelay.modeSlug }

    var body: some View {
        VStack(spacing: 12) {
            FlowHeader(title: "THE LOBBY", titleSize: 38) {
                if isHost {
                    confirmLeave = true
                } else {
                    app.leaveParty()
                }
            }
            .padding(.horizontal, 20)

            if let state {
                codeCard(state)
                summaryChips(state)

                rosterList(state)

                Spacer(minLength: 8)

                footer(state)
            }
        }
        .padding(.vertical, 10)
        .alert("End the party?", isPresented: $confirmLeave) {
            Button("End for Everyone", role: .destructive) { app.leaveParty() }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("You're the host — leaving closes the lobby for the whole car.")
        }
        .alert("Not enough riders yet", isPresented: $confirmShortStart) {
            Button("Start Anyway") { app.party.startRide() }
            Button("Wait for More", role: .cancel) {}
        } message: {
            let needed = state?.config.minPlayers ?? 2
            let joined = state?.connectedCount ?? 1
            let modeName = state?.config.modeName ?? "This mode"
            if state?.config.requiresEvenPlayers == true, joined % 2 != 0 {
                Text("\(modeName) needs an even number of riders (at least \(needed)) so both squads match up. \(joined) joined. Start anyway?")
            } else {
                Text("\(modeName) wants at least \(needed) players and only \(joined) joined. Start anyway?")
            }
        }
    }

    // MARK: - Header card

    private func codeCard(_ state: PartyState) -> some View {
        VStack(spacing: 8) {
            StickerText(text: state.partyName.uppercased(), size: 30)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 24)
            JoinCodePlate(code: state.code)
            StickerChip(text: "FRIENDS JOIN WITH PARTY NAME + CODE",
                        fill: TT.skyDeep, textColor: .white, textSize: 10)
        }
    }

    private func summaryChips(_ state: PartyState) -> some View {
        HStack(spacing: 8) {
            StickerChip(text: state.config.modeName.uppercased(),
                        fill: TT.tangerine, textColor: .white, textSize: 10)
            StickerChip(text: state.config.genreName.uppercased(),
                        fill: TT.grape, textColor: .white, textSize: 10)
            StickerChip(text: state.config.difficulty.displayName.uppercased(),
                        fill: TT.lime, textColor: .white, textSize: 10)
        }
    }

    // MARK: - Roster

    private func rosterList(_ state: PartyState) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(state.players) { player in
                    LobbyPlayerRow(player: player,
                                   isLocal: player.id == app.profile.playerID,
                                   canAssignRoles: isHost,
                                   showTeams: isTeamRelay) { role in
                        let newRole: PartyRole = player.role == role ? .none : role
                        app.party.assignRole(newRole, to: player.id)
                    } assignTeam: { team in
                        let newTeam: Int? = player.teamIndex == team ? nil : team
                        app.party.assignTeam(newTeam, to: player.id)
                    }
                }
                if state.players.count == 1 {
                    StickerChip(text: "WAITING FOR RIDERS TO HOP IN…",
                                fill: TT.paper, textSize: 12)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(_ state: PartyState) -> some View {
        if isHost {
            Button {
                if state.meetsPlayerRequirement {
                    app.party.startRide()
                } else {
                    confirmShortStart = true
                }
            } label: {
                RoadSignLabel(title: "Start Game")
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("lobby-start")
            .padding(.bottom, 18)
        } else {
            StickerChip(text: "WAITING FOR THE HOST TO START…",
                        fill: TT.sunshine, textSize: 12)
                .padding(.bottom, 22)
                .accessibilityIdentifier("lobby-waiting")
        }
    }
}

// MARK: - Roster row

private struct LobbyPlayerRow: View {
    var player: PartyPlayerState
    var isLocal: Bool
    var canAssignRoles: Bool
    var showTeams: Bool
    var assign: (PartyRole) -> Void
    var assignTeam: (Int) -> Void

    private var dimmed: Bool { player.presence != .connected }

    var body: some View {
        HStack(spacing: 12) {
            AvatarHead(color: TT.avatarColors[player.colorIndex % TT.avatarColors.count],
                       expression: dimmed ? .sad : .happy, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(isLocal ? "\(player.name) (You)" : player.name)
                    .font(TT.font(16, .black))
                    .foregroundStyle(TT.ink)
                    .lineLimit(1)
                presenceChip
            }

            Spacer(minLength: 8)

            if showTeams {
                teamControls
            } else {
                roleControls
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sticker(RoundedRectangle(cornerRadius: 16),
                 fill: isLocal ? TT.sunshine.opacity(0.9) : TT.paper)
        .opacity(dimmed ? 0.55 : 1)
        .saturation(player.presence == .left ? 0.2 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: player.presence)
        .accessibilityIdentifier("lobby-player-\(player.name)")
    }

    @ViewBuilder
    private var presenceChip: some View {
        switch player.presence {
        case .connected:
            EmptyView()
        case .dropped:
            StickerChip(text: "RECONNECTING…", fill: TT.tangerine,
                        textColor: .white, textSize: 8)
        case .left:
            StickerChip(text: "LEFT THE CAR", fill: TT.asphalt,
                        textColor: .white, textSize: 8)
        }
    }

    @ViewBuilder
    private var roleControls: some View {
        if canAssignRoles, player.presence == .connected {
            HStack(spacing: 6) {
                roleButton(.pilot, label: "PILOT", fill: TT.cherry)
                roleButton(.copilot, label: "COPILOT", fill: TT.skyDeep)
            }
        } else if let badge = player.role.badge {
            StickerChip(text: badge, fill: player.role == .pilot ? TT.cherry : TT.skyDeep,
                        textColor: .white, textSize: 9)
        }
    }

    private func roleButton(_ role: PartyRole, label: String, fill: Color) -> some View {
        Button {
            assign(role)
        } label: {
            StickerChip(text: label,
                        fill: player.role == role ? fill : TT.paper,
                        textColor: player.role == role ? .white : TT.ink,
                        textSize: 9)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("role-\(role.rawValue)-\(player.name)")
    }

    // MARK: - Team Relay squad assignment

    @ViewBuilder
    private var teamControls: some View {
        if canAssignRoles, player.presence == .connected {
            HStack(spacing: 6) {
                teamButton(0, label: "TEAM 1", fill: TT.lime)
                teamButton(1, label: "TEAM 2", fill: TT.sky)
            }
        } else if let team = player.teamIndex {
            StickerChip(text: "TEAM \(team + 1)", fill: team == 0 ? TT.lime : TT.sky,
                        textColor: .white, textSize: 9)
        }
    }

    private func teamButton(_ team: Int, label: String, fill: Color) -> some View {
        Button {
            assignTeam(team)
        } label: {
            StickerChip(text: label,
                        fill: player.teamIndex == team ? fill : TT.paper,
                        textColor: player.teamIndex == team ? .white : TT.ink,
                        textSize: 9)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("team-\(team)-\(player.name)")
    }
}
