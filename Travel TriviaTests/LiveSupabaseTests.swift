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

    /// Part of the genre-content-routing full scan: confirms every live
    /// genre slug either has real live question content, or — for genres
    /// whose migration hasn't been pushed yet (see the session notes on
    /// `20260726210000_wyr_mqm_content.sql` and the later genre-batch-2 /
    /// audio-genre migrations) — falls back to that *same* genre's own
    /// bundled pack rather than silently landing on Riddle Realm. A live
    /// `genres.slug` that didn't match its bundled counterpart would be
    /// exactly the kind of bug that produces "every genre plays the same
    /// content" symptoms, so this is a real regression guard, not just a
    /// diagnostic.
    @Test func everyLiveGenreHasLiveOrMatchingBundledContent() async throws {
        guard SupabaseService.client != nil else { return }
        let catalog = ContentCatalog()
        await catalog.refresh()
        guard catalog.source == .live else {
            Issue.record("credentials are configured but the live fetch failed — check the key")
            return
        }
        for genre in catalog.genres {
            let hasLivePack = catalog.questionPack(genreSlug: genre.slug) != nil
            let bundledFallback = SeedQuestions.packs[genre.slug]
            #expect(hasLivePack || bundledFallback != nil,
                    "\(genre.slug): no live content AND no bundled fallback — this genre would silently deal Riddle Realm")
        }
    }
}
