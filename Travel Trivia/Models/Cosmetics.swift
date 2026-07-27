//
//  Cosmetics.swift
//  Travel Trivia
//
//  DRAFT starter cosmetic catalog for My Garage — proposed by this session,
//  not previously itemized in the design vault (see the session report).
//  Kept small on purpose per the build prompt ("don't over-build the
//  catalog this session"): 3 avatar categories, 3 car categories, a
//  fast-early-win free item in each plus a couple of badge-gated ones,
//  matching the "fast early wins, bigger items later" unlock pacing called
//  out in the avatars-and-rewards design doc.
//

import Foundation
import SwiftData

struct CosmeticItem: Identifiable, Equatable {
    enum Category: String {
        case hat, accessory, sticker          // avatar
        case carColor, carDecal, carAccessory  // My Garage car
    }

    let id: String
    let category: Category
    let displayName: String
    /// Nil = free/starter, unlocked from the very first launch.
    let unlockBadgeID: String?
}

enum CosmeticCatalog {
    // MARK: Avatar

    static let hats: [CosmeticItem] = [
        .init(id: "hat-none", category: .hat, displayName: "No Hat", unlockBadgeID: nil),
        .init(id: "hat-cap", category: .hat, displayName: "Road Cap", unlockBadgeID: nil),
        .init(id: "hat-party", category: .hat, displayName: "Party Hat",
              unlockBadgeID: BadgeCatalog.perfectRoundID),
        .init(id: "hat-crown", category: .hat, displayName: "Champ Crown",
              unlockBadgeID: BadgeCatalog.modeMasteryID("three-strikes")),
    ]

    static let accessories: [CosmeticItem] = [
        .init(id: "acc-none", category: .accessory, displayName: "None", unlockBadgeID: nil),
        .init(id: "acc-shades", category: .accessory, displayName: "Shades", unlockBadgeID: nil),
        .init(id: "acc-bowtie", category: .accessory, displayName: "Bow Tie",
              unlockBadgeID: BadgeCatalog.genreCompletionID("riddle-realm")),
        .init(id: "acc-flower", category: .accessory, displayName: "Flower Crown",
              unlockBadgeID: BadgeCatalog.comebackID),
    ]

    static let stickers: [CosmeticItem] = [
        .init(id: "sticker-none", category: .sticker, displayName: "None", unlockBadgeID: nil),
        .init(id: "sticker-star", category: .sticker, displayName: "Star Cheek", unlockBadgeID: nil),
        .init(id: "sticker-heart", category: .sticker, displayName: "Heart Cheek",
              unlockBadgeID: BadgeCatalog.genreCompletionID("time-machine")),
        .init(id: "sticker-lightning", category: .sticker, displayName: "Lightning Bolt",
              unlockBadgeID: BadgeCatalog.curveballCaughtID),
    ]

    // MARK: My Garage car (distinct from Our Ride's shared vehicle)

    static let carColors: [CosmeticItem] = [
        .init(id: "car-cherry", category: .carColor, displayName: "Cherry Red", unlockBadgeID: nil),
        .init(id: "car-lime", category: .carColor, displayName: "Lime Green", unlockBadgeID: nil),
        .init(id: "car-sunshine", category: .carColor, displayName: "Sunshine Yellow",
              unlockBadgeID: BadgeCatalog.genreCompletionID("superlative-showdown")),
        .init(id: "car-grape", category: .carColor, displayName: "Grape Purple",
              unlockBadgeID: BadgeCatalog.modeMasteryID("copilots-curveball")),
    ]

    static let carDecals: [CosmeticItem] = [
        .init(id: "decal-none", category: .carDecal, displayName: "No Decal", unlockBadgeID: nil),
        .init(id: "decal-flames", category: .carDecal, displayName: "Flames", unlockBadgeID: nil),
        .init(id: "decal-stars", category: .carDecal, displayName: "Stars",
              unlockBadgeID: BadgeCatalog.modeMasteryID("elimination-bracket")),
    ]

    static let carAccessories: [CosmeticItem] = [
        .init(id: "cartop-none", category: .carAccessory, displayName: "Bare Roof", unlockBadgeID: nil),
        .init(id: "cartop-surfboard", category: .carAccessory, displayName: "Surfboard", unlockBadgeID: nil),
        .init(id: "cartop-antenna", category: .carAccessory, displayName: "Antenna Flag",
              unlockBadgeID: BadgeCatalog.modeMasteryID("team-relay")),
    ]

    static func item(_ id: String, in items: [CosmeticItem]) -> CosmeticItem {
        items.first { $0.id == id } ?? items[0]
    }
}

/// This player's equipped avatar cosmetics. Local-only, one row per
/// `playerID` — never leaves the device.
@Model
final class AvatarLoadout {
    var playerID: UUID
    var hatID: String
    var accessoryID: String
    var stickerID: String

    init(playerID: UUID) {
        self.playerID = playerID
        self.hatID = "hat-none"
        self.accessoryID = "acc-none"
        self.stickerID = "sticker-none"
    }
}

/// This player's equipped My Garage car — a personal, individually-owned
/// car distinct from "Our Ride" (the shared seat-picker vehicle).
@Model
final class CarLoadout {
    var playerID: UUID
    var colorID: String
    var decalID: String
    var accessoryID: String

    init(playerID: UUID) {
        self.playerID = playerID
        self.colorID = "car-cherry"
        self.decalID = "decal-none"
        self.accessoryID = "cartop-none"
    }
}
