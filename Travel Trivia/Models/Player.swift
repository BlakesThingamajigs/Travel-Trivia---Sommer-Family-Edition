//
//  Player.swift
//  Travel Trivia
//
//  Local mock-party state for the single-device vertical slice. Real
//  Multipeer-backed parties replace the mock construction later, but the
//  shape (seats, scores, strikes) is the real one.
//

import Foundation
import SwiftData

@Model
final class Player {
    var name: String
    var colorIndex: Int
    var seatIndex: Int
    var isUser: Bool
    /// Chance a simulated player answers correctly. Unused for the real user.
    var accuracy: Double
    var score: Int
    var strikes: Int
    /// How this player did on the question currently being revealed.
    var lastAnswerCorrect: Bool?

    init(name: String, colorIndex: Int, seatIndex: Int, isUser: Bool = false, accuracy: Double = 0.65) {
        self.name = name
        self.colorIndex = colorIndex
        self.seatIndex = seatIndex
        self.isUser = isUser
        self.accuracy = accuracy
        self.score = 0
        self.strikes = 0
    }

    var isOut: Bool { strikes >= GameEngine.maxStrikes }
    var strikesRemaining: Int { max(0, GameEngine.maxStrikes - strikes) }
}
