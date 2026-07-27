//
//  WelcomeSignInView.swift
//  Travel Trivia
//
//  One-time first-launch offer to sign in, shown before Main Menu ever
//  appears. Purely an earlier, optional chance at the same Host Account
//  sign-in Settings already offers — hosting a party has never required an
//  account and still doesn't; skipping here changes nothing about that.
//  Skip is permanent (LocalProfile.hasSeenWelcomeSignInPrompt) — this
//  screen never shows again once dismissed, either way.
//

import SwiftUI

struct WelcomeSignInView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 2) {
                StickerText(text: "TRAVEL", size: 44, fill: TT.sunshine)
                    .rotationEffect(.degrees(-3))
                StickerText(text: "TRIVIA", size: 50, fill: .white)
                    .rotationEffect(.degrees(2))
            }

            StickerChip(text: "Sign in to keep hosting from this phone across launches",
                        fill: TT.paper, textSize: 13)
                .padding(.horizontal, 30)
                .multilineTextAlignment(.center)

            Text("Only the party host ever needs this — joining friends never do. Entirely optional; you can always sign in later from Settings.")
                .font(TT.font(13, .bold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

            if let message = app.auth.lastErrorMessage {
                Text(message)
                    .font(TT.font(12, .bold))
                    .foregroundStyle(TT.cherry)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .accessibilityIdentifier("welcome-auth-error")
            }

            VStack(spacing: 12) {
                signInButton(label: "Sign in with Apple", icon: "apple.logo") {
                    await app.auth.signInWithApple()
                }
                .accessibilityIdentifier("welcome-signin-apple")

                signInButton(label: "Sign in with Google", icon: "g.circle.fill") {
                    await app.auth.signInWithGoogle()
                }
                .accessibilityIdentifier("welcome-signin-google")
            }
            .padding(.horizontal, 30)
            .padding(.top, 6)

            Button {
                app.dismissWelcomeSignInPrompt()
            } label: {
                Text("SKIP")
                    .font(TT.font(15, .black))
                    .foregroundStyle(.white.opacity(0.85))
                    .underline()
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityIdentifier("welcome-skip")

            Spacer()
            Spacer()
        }
        .padding(.vertical, 10)
        .disabled(app.auth.isSigningIn)
        // A returning host with an already-restored session (or one who
        // just signed in from here) shouldn't linger on a moot prompt.
        .onChange(of: app.auth.isSignedIn) { _, signedIn in
            if signedIn { app.dismissWelcomeSignInPrompt() }
        }
        .task {
            if app.auth.isSignedIn { app.dismissWelcomeSignInPrompt() }
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
            .padding(.vertical, 13)
            .sticker(RoundedRectangle(cornerRadius: 14), fill: .white, lineWidth: 2.5)
        }
        .buttonStyle(.bubble)
        .disabled(app.auth.isSigningIn)
    }
}
