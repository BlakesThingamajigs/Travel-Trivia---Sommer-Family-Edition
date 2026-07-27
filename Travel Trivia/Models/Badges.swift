//
//  Badges.swift
//  Travel Trivia
//
//  DRAFT badge list — proposed starter set, not a confirmed design spec
//  (flagged in the session report). Badges are earned by the local player
//  only (no accounts for non-host riders, so "party-wide" isn't
//  representable without breaking the no-account model) and persist
//  forever on this device once earned — they're the unlock currency for
//  My Garage cosmetics.
//

import Foundation
import SwiftData
import SwiftUI

/// A single earned badge, persisted locally forever once awarded. Keyed by
/// `playerID` (LocalProfile's stable device id) rather than by party, since
/// there's no server-side identity to award these against.
@Model
final class EarnedBadge {
    var playerID: UUID
    var badgeID: String
    var earnedAt: Date

    init(playerID: UUID, badgeID: String, earnedAt: Date = .now) {
        self.playerID = playerID
        self.badgeID = badgeID
        self.earnedAt = earnedAt
    }
}

/// Display metadata for a badge, resolved on demand rather than stored —
/// the catalog can be re-worded/re-themed without touching earned records,
/// which only ever store the stable `id`.
struct BadgeDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let fill: Color
}

/// DRAFT badge catalog (proposed by this session, not previously itemized
/// in the design vault — see the session report). Five badge *types*;
/// genre completion and mode mastery expand to one badge per genre/mode.
enum BadgeCatalog {
    static func genreCompletionID(_ genreSlug: String) -> String { "genre-complete-\(genreSlug)" }
    static func modeMasteryID(_ modeSlug: String) -> String { "mode-mastery-\(modeSlug)" }
    static let perfectRoundID = "perfect-round"
    static let comebackID = "comeback"
    static let curveballCaughtID = "curveball-caught"

    static func genreCompletionBadges(catalog: ContentCatalog) -> [BadgeDefinition] {
        catalog.genres.map {
            BadgeDefinition(id: genreCompletionID($0.slug),
                             title: "\($0.displayName) Finisher",
                             subtitle: "Finish a full round of \($0.displayName)",
                             fill: TT.lime)
        }
    }

    static func modeMasteryBadges(catalog: ContentCatalog) -> [BadgeDefinition] {
        catalog.modes.map {
            BadgeDefinition(id: modeMasteryID($0.slug),
                             title: "\($0.displayName) Champ",
                             subtitle: "Win a game of \($0.displayName)",
                             fill: TT.grape)
        }
    }

    static let perfectRound = BadgeDefinition(
        id: perfectRoundID, title: "Perfect Round",
        subtitle: "Finish a round without taking a single strike", fill: TT.sunshine)
    static let comeback = BadgeDefinition(
        id: comebackID, title: "Comeback Kid",
        subtitle: "Win after being dead last mid-round", fill: TT.tangerine)
    static let curveballCaught = BadgeDefinition(
        id: curveballCaughtID, title: "Curveball Caught",
        subtitle: "Answer a Copilot's Curveball question correctly", fill: TT.bubblegum)

    static func allBadges(catalog: ContentCatalog) -> [BadgeDefinition] {
        genreCompletionBadges(catalog: catalog) + modeMasteryBadges(catalog: catalog)
            + [perfectRound, comeback, curveballCaught]
    }

    static func definition(for id: String, catalog: ContentCatalog) -> BadgeDefinition? {
        allBadges(catalog: catalog).first { $0.id == id }
    }
}
