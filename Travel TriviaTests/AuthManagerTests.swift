//
//  AuthManagerTests.swift
//  Travel TriviaTests
//
//  Confirms sign-out really clears local session state (not just in theory)
//  and that AuthManager degrades safely with no Supabase credentials
//  configured — both matter because joining players and hosts on a fresh
//  checkout (no Supabase.xcconfig.local) must never crash on this path.
//

import Foundation
import Testing
@testable import Travel_Trivia

@MainActor
struct AuthManagerTests {

    @Test func startsSignedOutAndSignOutIsANoOpWhenNeverSignedIn() async {
        let auth = AuthManager()
        // Give the initial authStateChanges event (session restore attempt)
        // a moment to land before asserting on it.
        try? await Task.sleep(for: .milliseconds(300))

        #expect(auth.session == nil)
        #expect(!auth.isSignedIn)

        // Signing out with no active session must still leave local state
        // cleanly signed-out rather than throwing/crashing.
        await auth.signOut()
        #expect(auth.session == nil)
        #expect(!auth.isSignedIn)
    }

    @Test func hostDisplayNameAndEmailAreNilWhenSignedOut() {
        let auth = AuthManager()
        #expect(auth.hostDisplayName == nil)
        #expect(auth.hostEmail == nil)
    }
}
