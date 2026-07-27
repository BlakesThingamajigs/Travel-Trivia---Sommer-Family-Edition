//
//  LiveSupabaseTests.swift
//  Travel TriviaTests
//
//  Hits the real Supabase project (needs network + Supabase.xcconfig.local).
//  Exists so a broken key can never hide behind the bundled fallback: if
//  credentials are configured, the live fetch must actually succeed.
//

import Foundation
import Testing
@testable import Travel_Trivia

@MainActor
struct LiveSupabaseTests {

    @Test func liveCatalogFetchPopulatesModesGenresAndQuestions() async throws {
        guard SupabaseService.client != nil else {
            // No local credentials — nothing to verify (e.g. a fresh checkout).
            return
        }
        let catalog = ContentCatalog()
        await catalog.refresh()

        #expect(catalog.source == .live,
                "credentials are configured but the live fetch failed — check the key")
        #expect(catalog.modes.count == 6)
        #expect(catalog.genres.count == 12)
        let riddles = try #require(catalog.questionPack(genreSlug: "riddle-realm"))
        #expect(riddles.count >= 16)
        for question in riddles {
            #expect(question.options.count == 6)
        }
    }
}
