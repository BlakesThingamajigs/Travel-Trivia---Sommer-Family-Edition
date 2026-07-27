//
//  JoinGameView.swift
//  Travel Trivia
//
//  Join a Game: party name + 4-digit code + your display name (defaults to
//  the locally saved one), then a real Multipeer discovery attempt with
//  clear searching / not-found / retry states. Success lands in the same
//  Lobby the host sees.
//

import SwiftUI

struct JoinGameView: View {
    @Environment(AppModel.self) private var app

    @State private var partyName = ""
    @State private var code = ""
    @State private var displayName = ""

    private var status: PartySession.Status { app.party.status }
    private var isBusy: Bool {
        status == .searching || status == .connecting
    }

    var body: some View {
        VStack(spacing: 16) {
            FlowHeader(title: "JOIN A GAME", titleSize: 36) {
                app.party.leaveParty()
                app.route = .menu
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 16) {
                    StickerTextField(label: "Party Name", text: $partyName,
                                     prompt: "Sommer Road Trip")
                        .accessibilityIdentifier("join-party-name")
                    StickerTextField(label: "4-Digit Code", text: $code,
                                     prompt: "0000", keyboard: .numberPad, maxLength: 4)
                        .accessibilityIdentifier("join-code")
                    StickerTextField(label: "Your Name", text: $displayName,
                                     prompt: "Who's riding?")
                        .accessibilityIdentifier("join-display-name")

                    statusArea
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
            }
            .scrollIndicators(.hidden)

            Button(action: attemptJoin) {
                RoadSignLabel(title: isBusy ? "Searching…" : "Hop In",
                              color: TT.tangerine)
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("join-submit")
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)
            .padding(.bottom, 18)
        }
        .padding(.vertical, 10)
        .onAppear {
            displayName = app.profile.displayName == "Player" ? "" : app.profile.displayName
        }
    }

    private var canSubmit: Bool {
        !isBusy
            && !partyName.trimmingCharacters(in: .whitespaces).isEmpty
            && code.count == 4
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func attemptJoin() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        app.profile.displayName = name
        app.joinParty(partyName: partyName.trimmingCharacters(in: .whitespaces), code: code)
    }

    @ViewBuilder
    private var statusArea: some View {
        switch status {
        case .searching:
            searchingChip("LOOKING FOR THE PARTY…")
        case .connecting:
            searchingChip("FOUND IT! HOPPING IN…")
        case .failed(.notFound):
            VStack(spacing: 8) {
                StickerChip(text: "NO PARTY FOUND NEARBY",
                            fill: TT.cherry, textColor: .white, textSize: 12)
                Text("Double-check the party name and code with your host — and make sure their phone is close by.")
                    .font(TT.font(13, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("join-not-found")
        case .failed(.lost):
            StickerChip(text: "LOST THE PARTY — TRY AGAIN",
                        fill: TT.cherry, textColor: .white, textSize: 12)
        case .idle, .hosting, .connected, .reconnecting:
            EmptyView()
        }
    }

    private func searchingChip(_ text: String) -> some View {
        StickerChip(text: text, fill: TT.sunshine, textSize: 12)
            .transition(.scale.combined(with: .opacity))
            .accessibilityIdentifier("join-searching")
    }
}
