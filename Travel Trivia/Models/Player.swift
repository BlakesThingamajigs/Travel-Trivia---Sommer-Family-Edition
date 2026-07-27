//
//  Player.swift
//  Travel Trivia
//
//  The render-side party roster. In a real Multipeer party these rows are a
//  pure mirror of the synced PartyState (rebuilt on every snapshot); in
//  practice mode the engine seats and simulates them locally. Either way
//  the screens only ever read this one shape.
//

import Foundation
import SwiftData

@Model
final class Player {
    /// Unseated (still picking in Our Ride).
    static let noSeat = -1

    var name: String
    var colorIndex: Int
    var seatIndex: Int
    var isUser: Bool
    /// Chance a simulated player answers correctly. Practice mode only.
    var accuracy: Double
    var score: Int
    var strikes: Int
    /// How this player did on the question currently being revealed.
    var lastAnswerCorrect: Bool?
    /// Stable cross-device id from the synced party; nil for practice bots.
    var remoteID: UUID?
    var roleRaw: String
    var presenceRaw: String
    /// Team Relay squad (0 or 1); nil when unassigned or not in that mode.
    var teamIndex: Int?
    /// How many wrong answers this player can take before they're out.
    /// Mode-aware (Elimination Bracket: 1, Team Relay: effectively
    /// unlimited, everything else: `GameEngine.maxStrikes`) — synced from
    /// the party's mode so `isOut` reads correctly everywhere. Nil in
    /// practice, which is always plain Three Strikes.
    var maxStrikesOverride: Int?

    init(name: String, colorIndex: Int, seatIndex: Int, isUser: Bool = false,
         accuracy: Double = 0.65, remoteID: UUID? = nil) {
        self.name = name
        self.colorIndex = colorIndex
        self.seatIndex = seatIndex
        self.isUser = isUser
        self.accuracy = accuracy
        self.score = 0
        self.strikes = 0
        self.remoteID = remoteID
        self.roleRaw = PartyRole.none.rawValue
        self.presenceRaw = PlayerPresence.connected.rawValue
    }

    var role: PartyRole {
        get { PartyRole(rawValue: roleRaw) ?? .none }
        set { roleRaw = newValue.rawValue }
    }

    var presence: PlayerPresence {
        get { PlayerPresence(rawValue: presenceRaw) ?? .connected }
        set { presenceRaw = newValue.rawValue }
    }

    var isSeated: Bool { seatIndex != Player.noSeat }
    var effectiveMaxStrikes: Int { maxStrikesOverride ?? GameEngine.maxStrikes }
    var isOut: Bool { strikes >= effectiveMaxStrikes }
    var strikesRemaining: Int { max(0, effectiveMaxStrikes - strikes) }
}
