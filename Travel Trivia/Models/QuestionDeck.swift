//
//  QuestionDeck.swift
//  Travel Trivia
//
//  Deals the deck for a party game: filters the seed pack by difficulty
//  tier and shuffles each question's display options. Riddle Realm is the
//  only genre with content today, so every genre slug deals from the same
//  pack — the routing is real, the content catalog just hasn't caught up.
//

import Foundation

enum QuestionDeck {
    static func deal(genreSlug: String, tier: DifficultyTier,
                     seed: UInt64? = nil) -> [TriviaQuestion] {
        var generator: any RandomNumberGenerator = seed.map { SeededGenerator(seed: $0) }
            ?? SystemRandomNumberGenerator()
        let allowed = tier.allowedDifficulties
        let pack = SeedQuestions.riddleRealm.filter { allowed.contains($0.difficulty) }
        return pack.map { $0.shufflingOptions(using: &generator) }
    }
}
