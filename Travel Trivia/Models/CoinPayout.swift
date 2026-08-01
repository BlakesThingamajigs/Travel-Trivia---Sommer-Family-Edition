//
//  CoinPayout.swift
//  Travel Trivia
//
//  Coin payout math for winning a round, kept in this one spot so the
//  scheme can be tuned without hunting through GameEngine. Confirmed final.
//

import Foundation

enum CoinPayout {
    /// Coins for winning any game, before difficulty/mode adjustments.
    static let baseWin = 10

    /// Bonus on top of the base+difficulty reward for winning a
    /// higher-risk/harder mode.
    static let harderModeBonus = 5
    static let harderModeSlugs: Set<String> = [
        DoubleOrNothing.modeSlug, Elimination.bracketModeSlug,
    ]

    static func difficultyMultiplier(_ tier: DifficultyTier) -> Double {
        switch tier {
        case .littleOnes: 1
        case .familyMix: 1.5
        case .grownUp: 2
        }
    }

    /// Coins awarded for winning a round in `modeSlug` at `difficulty`.
    static func coinsForWin(modeSlug: String, difficulty: DifficultyTier) -> Int {
        let scaled = Double(baseWin) * difficultyMultiplier(difficulty)
        let bonus = harderModeSlugs.contains(modeSlug) ? harderModeBonus : 0
        return Int(scaled.rounded()) + bonus
    }
}
