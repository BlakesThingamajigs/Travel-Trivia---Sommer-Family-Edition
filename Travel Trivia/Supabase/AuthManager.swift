//
//  AuthManager.swift
//  Travel Trivia
//
//  Real host authentication: Sign in with Apple (native
//  ASAuthorizationAppleIDProvider) and Google (Supabase Auth's OAuth
//  provider via ASWebAuthenticationSession), both bridged into a Supabase
//  Auth session. Only the party HOST ever touches this — joining players
//  never authenticate (see PartySession's join flow, which only ever
//  exchanges playerID/name over Multipeer, never Supabase).
//
//  COPPA-driven constraint: nothing beyond the auth identity itself (id,
//  name, email as supplied by the provider) ever leaves this object. Local
//  profile data — avatar, score, badges, cosmetics — is never written to
//  Supabase from here or anywhere else.
//
//  Session persistence is handled by the Supabase SDK's default
//  Keychain-backed local storage: subscribing to `auth.authStateChanges`
//  below both restores any existing session on launch (the `.initialSession`
//  event) and keeps `session` current afterward, so the host is never asked
//  to sign in again just because the app relaunched.
//

import Foundation
import Observation
import Supabase
import AuthenticationServices
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

@Observable
@MainActor
final class AuthManager: NSObject {

    /// The custom URL scheme Google's OAuth flow redirects back into after
    /// Supabase finishes the provider handshake. Must be registered as a
    /// CFBundleURLSchemes entry in Info.plist (done) and added to the
    /// Supabase project's Auth > URL Configuration > Redirect URLs
    /// allow-list (dashboard-side, a human must do this).
    static let redirectURL = URL(string: "com.blakesthingamajigs.travel-trivia://login-callback")!

    private(set) var session: Session?
    /// True until the first `authStateChanges` event lands (session restore
    /// from Keychain, or confirmation there's nothing to restore).
    private(set) var isRestoringSession = true
    private(set) var isSigningIn = false
    var lastErrorMessage: String?

    var isSignedIn: Bool { session != nil }

    var hostDisplayName: String? {
        guard let user = session?.user else { return nil }
        if let name = user.userMetadata["full_name"]?.stringValue, !name.isEmpty { return name }
        if let name = user.userMetadata["name"]?.stringValue, !name.isEmpty { return name }
        return user.email
    }

    var hostEmail: String? { session?.user.email }

    @ObservationIgnored private var authStateTask: Task<Void, Never>?
    @ObservationIgnored private var appleContinuation: CheckedContinuation<ASAuthorization, Error>?
    @ObservationIgnored private var currentAppleController: ASAuthorizationController?
    @ObservationIgnored private var currentNonce: String?

    override init() {
        super.init()
        guard let client = SupabaseService.client else {
            isRestoringSession = false
            return
        }
        authStateTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                guard let self else { return }
                self.session = session
                if event == .initialSession {
                    self.isRestoringSession = false
                }
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Apple

    func signInWithApple() async {
        guard let client = SupabaseService.client else {
            lastErrorMessage = "Sign-in isn't configured on this build."
            return
        }
        lastErrorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        let nonce = Self.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])

        do {
            let authorization = try await performAppleRequest(controller)
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                lastErrorMessage = "Apple didn't return a usable identity token."
                return
            }
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // Silent: the host backed out of the system sheet on purpose.
        } catch {
            lastErrorMessage = Self.presentableAppleErrorMessage(for: error)
        }
    }

    /// ASAuthorizationController reports most real failures as `.unknown`
    /// (including "this device isn't signed in to an Apple Account in
    /// Settings," the most common one hosts hit) — its raw
    /// localizedDescription is a cryptic error-code string, not something
    /// to show a host.
    private static func presentableAppleErrorMessage(for error: Error) -> String {
        guard let authError = error as? ASAuthorizationError else {
            return "Sign in with Apple couldn't complete. Please try again."
        }
        switch authError.code {
        case .unknown:
            return "Sign in with Apple isn't available — make sure this device is signed in to an Apple Account in Settings, then try again."
        default:
            return "Sign in with Apple couldn't complete. Please try again."
        }
    }

    private func performAppleRequest(_ controller: ASAuthorizationController) async throws -> ASAuthorization {
        controller.delegate = self
        controller.presentationContextProvider = self
        currentAppleController = controller
        return try await withCheckedThrowingContinuation { continuation in
            appleContinuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        guard let client = SupabaseService.client else {
            lastErrorMessage = "Sign-in isn't configured on this build."
            return
        }
        lastErrorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            _ = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: Self.redirectURL
            ) { session in
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Silent: the host dismissed the web sheet on purpose.
        } catch {
            lastErrorMessage = "Sign in with Google couldn't complete. Please try again."
        }
    }

    // MARK: - Sign out

    func signOut() async {
        guard let client = SupabaseService.client else {
            session = nil
            return
        }
        do {
            try await client.auth.signOut()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        // Belt-and-suspenders: clear local state immediately even if the
        // network call above failed, so the UI never looks signed-in after
        // the host explicitly asked to sign out.
        session = nil
    }

    // MARK: - Nonce helpers (Apple's documented pattern for replay-proof ID tokens)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess, "Unable to generate nonce.")
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                              didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            self.appleContinuation?.resume(returning: authorization)
            self.appleContinuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                              didCompleteWithError error: Error) {
        Task { @MainActor in
            self.appleContinuation?.resume(throwing: error)
            self.appleContinuation = nil
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { AuthManager.keyWindow() }
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { AuthManager.keyWindow() }
    }
}

extension AuthManager {
    #if canImport(UIKit)
    /// Re-resolved fresh on every call (never cached), since Stage Manager
    /// and Split View can resize or re-key the window between when this
    /// delegate is registered and when it's actually asked to anchor a
    /// sheet. Falls through key window -> any window -> a window newly
    /// attached to a live scene, so we never hand back a disconnected,
    /// zero-frame anchor (which would present the sign-in sheet off-screen).
    fileprivate static func keyWindow() -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let windows = windowScenes.flatMap { $0.windows }
        if let key = windows.first(where: { $0.isKeyWindow }) {
            return key
        }
        if let any = windows.first {
            return any
        }
        guard let scene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first else {
            // Unreachable: this delegate only fires while presenting an auth
            // sheet from an active scene, so a connected UIWindowScene always
            // exists here. Asserting (rather than falling back to the
            // deprecated scene-less UIWindow initializers) means we can
            // never hand ASAuthorizationController a disconnected anchor.
            preconditionFailure("AuthManager.keyWindow() called with no connected UIWindowScene")
        }
        return UIWindow(windowScene: scene)
    }
    #else
    fileprivate static func keyWindow() -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
    #endif
}
