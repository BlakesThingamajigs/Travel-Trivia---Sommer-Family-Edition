//
//  SettingsView.swift
//  Travel Trivia
//
//  Local settings: display name, the Shuffle Genres game rule, and the
//  audio output preference — routes real narration and sound-genre clip
//  playback via AudioDirector. The account section stays a visual stub —
//  real Google/Apple sign-in is deliberately not wired yet.
//

import SwiftUI

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
                StickerChip(text: "COMING SOON", fill: TT.asphalt,
                            textColor: .white, textSize: 9)
            }
            Text("Only the party host needs an account. Sign-in lights up in a future update.")
                .font(TT.font(12, .bold))
                .foregroundStyle(TT.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            stubSignInButton(label: "Sign in with Google", icon: "g.circle.fill")
            stubSignInButton(label: "Sign in with Apple", icon: "apple.logo")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sticker(RoundedRectangle(cornerRadius: 18), fill: TT.paper)
        .padding(.top, 6)
    }

    private func stubSignInButton(label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
            Text(label)
                .font(TT.font(15, .heavy))
        }
        .foregroundStyle(TT.ink.opacity(0.45))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(TT.ink.opacity(0.3), lineWidth: 2.5)
        }
    }
}
