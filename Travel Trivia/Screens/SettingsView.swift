//
//  SettingsView.swift
//  Travel Trivia
//
//  Local settings: display name, the Shuffle Genres game rule, and the
//  audio output preference — routes real narration and sound-genre clip
//  playback via AudioDirector. The Host Account section wires real
//  Google/Apple sign-in through AuthManager — only the party host ever
//  needs this; joining players never see it.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var profile = app.profile

        VStack(spacing: 14) {
            FlowHeader(title: "SETTINGS", titleSize: 38) {
                app.route = .menu
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 18) {
                    StickerTextField(label: "Your Name", text: $profile.displayName,
                                     prompt: "Who's riding?")
                        .accessibilityIdentifier("settings-name")

                    VStack(alignment: .leading, spacing: 8) {
                        StickerToggle(label: "Shuffle Genres", isOn: $profile.shuffleGenres)
                            .accessibilityIdentifier("settings-shuffle")
                        caption("When on, every game rolls a surprise genre instead of the one picked in Create Game.")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        StickerChip(text: "GAME AUDIO PLAYS FROM", fill: TT.sunshine, textSize: 11)
                        HStack(spacing: 12) {
                            ForEach(LocalProfile.AudioOutput.allCases) { output in
                                audioOption(output, current: $profile.audioOutput)
                            }
                        }
                        caption("Question narration and sound-genre clips route through this pick live.")
                    }

                    narratorVoiceSection

                    accountSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 10)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(TT.font(12, .bold))
            .foregroundStyle(.white.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var narratorVoiceSection: some View {
        let resolved = NarratorVoiceCatalog.resolve()
        return VStack(alignment: .leading, spacing: 8) {
            StickerChip(text: "NARRATOR VOICE", fill: TT.sunshine, textSize: 11)
            VStack(spacing: 10) {
                ForEach(NarratorPersona.allCases) { persona in
                    narratorPersonaRow(persona, availability: NarratorVoiceCatalog.availability(for: persona, resolved: resolved))
                }
            }
            caption("Question narration reads in this voice. Personas need an Enhanced or Premium voice downloaded on this phone — see Settings → Accessibility → Spoken Content → Voices.")
        }
    }

    /// A plain (non-Button) row container — the "select this persona" tap
    /// target and the "open Settings to download a voice" tap target are
    /// siblings inside it, never nested, since SwiftUI doesn't reliably
    /// route taps to a Button embedded inside another Button's label.
    private func narratorPersonaRow(_ persona: NarratorPersona, availability: NarratorVoiceCatalog.Availability) -> some View {
        let selected = app.progress.narratorVoicePreference.persona == persona
        let available = { if case .available = availability { true } else { false } }()

        return HStack(spacing: 12) {
            Button {
                app.progress.setNarratorPersona(selected ? nil : persona)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.displayName)
                        .font(TT.font(15, .heavy))
                        .foregroundStyle(available ? TT.ink : TT.ink.opacity(0.4))
                    Text(persona.tagline)
                        .font(TT.font(11, .bold))
                        .foregroundStyle(available ? TT.ink.opacity(0.65) : TT.ink.opacity(0.35))
                    switch availability {
                    case .available(let name):
                        Text(name.uppercased())
                            .font(TT.font(10, .black))
                            .foregroundStyle(TT.grape)
                    case .needsDownload:
                        Text("NEEDS DOWNLOADING")
                            .font(TT.font(10, .black))
                            .foregroundStyle(TT.cherry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!available)
            .accessibilityIdentifier("settings-narrator-\(persona.rawValue)")

            if !available {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("SETTINGS")
                        .font(TT.font(11, .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .sticker(RoundedRectangle(cornerRadius: 10), fill: TT.grape)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("settings-narrator-\(persona.rawValue)-open-settings")
            } else if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(TT.signGreen)
            }
        }
        .padding(14)
        .sticker(RoundedRectangle(cornerRadius: 16),
                 fill: selected ? TT.signGreen.opacity(0.15) : TT.paper)
    }

    private func audioOption(_ output: LocalProfile.AudioOutput,
                             current: Binding<LocalProfile.AudioOutput>) -> some View {
        let selected = current.wrappedValue == output
        return Button {
            current.wrappedValue = output
        } label: {
            VStack(spacing: 6) {
                Image(systemName: output == .bluetooth ? "car.fill" : "iphone")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(selected ? .white : TT.ink)
                Text(output.displayName.uppercased())
                    .font(TT.font(11, .black))
                    .foregroundStyle(selected ? .white : TT.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .sticker(RoundedRectangle(cornerRadius: 16),
                     fill: selected ? TT.signGreen : TT.paper)
        }
        .buttonStyle(.bubble)
        .accessibilityIdentifier("settings-audio-\(output.rawValue)")
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                StickerChip(text: "HOST ACCOUNT", fill: TT.grape,
                            textColor: .white, textSize: 11)
                if app.auth.isSignedIn {
                    StickerChip(text: "SIGNED IN", fill: TT.lime,
                                textColor: TT.ink, textSize: 9)
                }
            }

            if let message = app.auth.lastErrorMessage {
                Text(message)
                    .font(TT.font(12, .bold))
                    .foregroundStyle(TT.cherry)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings-auth-error")
            }

            if app.auth.isSignedIn {
                signedInRow
            } else {
                Text("Only the party host needs an account. Sign in to keep hosting from this phone across launches.")
                    .font(TT.font(12, .bold))
                    .foregroundStyle(TT.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                signInButton(label: "Sign in with Apple", icon: "apple.logo") {
                    await app.auth.signInWithApple()
                }
                .accessibilityIdentifier("settings-signin-apple")

                signInButton(label: "Sign in with Google", icon: "g.circle.fill") {
                    await app.auth.signInWithGoogle()
                }
                .accessibilityIdentifier("settings-signin-google")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(RoundedRectangle(cornerRadius: 18), fill: TT.paper)
        .padding(.top, 6)
    }

    private var signedInRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(TT.grape)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.auth.hostDisplayName ?? "Host")
                        .font(TT.font(14, .heavy))
                        .foregroundStyle(TT.ink)
                    if let email = app.auth.hostEmail {
                        Text(email)
                            .font(TT.font(11, .bold))
                            .foregroundStyle(TT.ink.opacity(0.6))
                    }
                }
            }

            Button {
                Task { await app.auth.signOut() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 14, weight: .bold))
                    Text("SIGN OUT")
                        .font(TT.font(14, .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .sticker(RoundedRectangle(cornerRadius: 12), fill: TT.cherry, lineWidth: 2.5)
            }
            .buttonStyle(.bubble)
            .accessibilityIdentifier("settings-signout")
        }
    }

    private func signInButton(label: String, icon: String,
                              action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                if app.auth.isSigningIn {
                    ProgressView().tint(TT.ink)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(label)
                    .font(TT.font(15, .heavy))
            }
            .foregroundStyle(TT.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .sticker(RoundedRectangle(cornerRadius: 12), fill: .white, lineWidth: 2.5)
        }
        .buttonStyle(.bubble)
        .disabled(app.auth.isSigningIn)
    }
}
