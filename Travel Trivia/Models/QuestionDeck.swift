//
//  QuestionDeck.swift
//  Travel Trivia
//
//  Deals the deck for a party game: picks the genre's pack (live Supabase
//  content when the catalog has it, bundled seeds otherwise), filters by
//  difficulty tier, and shuffles each question's display options.
//

import Foundation

enum QuestionDeck {
    static func deal(genreSlug: String, tier: DifficultyTier,
                     livePack: [TriviaQuestion]? = nil,
                     seed: UInt64? = nil) -> [TriviaQuestion] {
        var generator: any RandomNumberGenerator = seed.map { SeededGenerator(seed: $0) }
            ?? SystemRandomNumberGenerator()
        let pack = livePack ?? SeedQuestions.packs[genreSlug] ?? SeedQuestions.riddleRealm
        let allowed = tier.allowedDifficulties
        let filtered = pack.filter { allowed.contains($0.difficulty) }
        // A pack with nothing in the tier still has to deal a playable game.
        let dealt = filtered.isEmpty ? pack : filtered
        return dealt.shuffled(using: &generator)
            .map { $0.shufflingOptions(using: &generator) }
    }
}
