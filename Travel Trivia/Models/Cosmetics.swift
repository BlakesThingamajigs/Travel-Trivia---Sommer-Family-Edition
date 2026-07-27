//
//  Cosmetics.swift
//  Travel Trivia
//
//  DRAFT starter cosmetic catalog for My Garage — proposed by this session,
//  not previously itemized in the design vault (see the session report).
//  Kept small on purpose per the build prompt ("don't over-build the
//  catalog this session"): 3 avatar categories, 3 car categories, a
//  fast-early-win free item in each plus a few coin-priced ones.
//
//  Coin shop: badges stay pure achievements (BadgeCatalog/EarnedBadge,
//  untouched) — cosmetics unlock by spending coins instead of earning a
//  specific badge, so `price` (0 = free/starter) replaces the old
//  `unlockBadgeID` gate.
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
    /// 0 = free/starter, unlocked from the very first launch.
    let price: Int
}

enum CosmeticCatalog {
    // MARK: Avatar

    static let hats: [CosmeticItem] = [
        .init(id: "hat-none", category: .hat, displayName: "No Hat", price: 0),
        .init(id: "hat-cap", category: .hat, displayName: "Road Cap", price: 0),
        .init(id: "hat-party", category: .hat, displayName: "Party Hat", price: 40),
        .init(id: "hat-crown", category: .hat, displayName: "Champ Crown", price: 60),
    ]

    static let accessories: [CosmeticItem] = [
        .init(id: "acc-none", category: .accessory, displayName: "None", price: 0),
        .init(id: "acc-shades", category: .accessory, displayName: "Shades", price: 0),
        .init(id: "acc-bowtie", category: .accessory, displayName: "Bow Tie", price: 30),
        .init(id: "acc-flower", category: .accessory, displayName: "Flower Crown", price: 50),
    ]

    static let stickers: [CosmeticItem] = [
        .init(id: "sticker-none", category: .sticker, displayName: "None", price: 0),
        .init(id: "sticker-star", category: .sticker, displayName: "Star Cheek", price: 0),
        .init(id: "sticker-heart", category: .sticker, displayName: "Heart Cheek", price: 30),
        .init(id: "sticker-lightning", category: .sticker, displayName: "Lightning Bolt", price: 45),
    ]

    // MARK: My Garage car (distinct from Our Ride's shared vehicle)

    static let carColors: [CosmeticItem] = [
        .init(id: "car-cherry", category: .carColor, displayName: "Cherry Red", price: 0),
        .init(id: "car-lime", category: .carColor, displayName: "Lime Green", price: 0),
        .init(id: "car-sunshine", category: .carColor, displayName: "Sunshine Yellow", price: 35),
        .init(id: "car-grape", category: .carColor, displayName: "Grape Purple", price: 55),
    ]

    static let carDecals: [CosmeticItem] = [
        .init(id: "decal-none", category: .carDecal, displayName: "No Decal", price: 0),
        .init(id: "decal-flames", category: .carDecal, displayName: "Flames", price: 0),
        .init(id: "decal-stars", category: .carDecal, displayName: "Stars", price: 45),
    ]

    static let carAccessories: [CosmeticItem] = [
        .init(id: "cartop-none", category: .carAccessory, displayName: "Bare Roof", price: 0),
        .init(id: "cartop-surfboard", category: .carAccessory, displayName: "Surfboard", price: 0),
        .init(id: "cartop-antenna", category: .carAccessory, displayName: "Antenna Flag", price: 45),
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

/// This player's coin balance — the shop's spend currency, local-only and
/// per-player like everything else here (no syncing, per the COPPA-driven
/// local-only design).
@Model
final class CoinWallet {
    var playerID: UUID
    var balance: Int

    init(playerID: UUID) {
        self.playerID = playerID
        self.balance = 0
    }
}

/// A cosmetic this player has bought, persisted forever once purchased —
/// the coin-shop equivalent of `EarnedBadge`.
@Model
final class PurchasedCosmetic {
    var playerID: UUID
    var itemID: String

    init(playerID: UUID, itemID: String) {
        self.playerID = playerID
        self.itemID = itemID
    }
}
