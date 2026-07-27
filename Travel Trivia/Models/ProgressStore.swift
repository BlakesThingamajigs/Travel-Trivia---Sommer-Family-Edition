//
//  ProgressStore.swift
//  Travel Trivia
//
//  The local player's persisted progression: earned badges plus equipped
//  avatar/car cosmetics. Backed by its own disk-persisted SwiftData
//  container (see Travel_TriviaApp.swift) — deliberately separate from the
//  in-memory Player/party mirror, since this is the one piece of state
//  that's supposed to survive relaunches on this device. Keyed by
//  LocalProfile.playerID, never synced anywhere.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ProgressStore {
    private let context: ModelContext
    let playerID: UUID

    private(set) var earnedBadgeIDs: Set<String> = []
    private(set) var avatarLoadout: AvatarLoadout
    private(set) var carLoadout: CarLoadout

    /// Queued the instant a badge is newly earned; screens observe the
    /// front of the queue to fire the celebration moment, then call
    /// `acknowledgeCelebration()` to pop it and reveal the next one. A
    /// queue rather than a single value because a round can legitimately
    /// earn several badges in the same tick (e.g. a first-ever win earns
    /// genre completion, mode mastery, and perfect round at once) — each
    /// deserves its own moment rather than the last one silently winning.
    private(set) var celebrationQueue: [String] = []
    var pendingCelebrationBadgeID: String? { celebrationQueue.first }

    init(context: ModelContext, playerID: UUID) {
        self.context = context
        self.playerID = playerID

        let badgeFetch = FetchDescriptor<EarnedBadge>(
            predicate: #Predicate { $0.playerID == playerID })
        earnedBadgeIDs = Set(((try? context.fetch(badgeFetch)) ?? []).map(\.badgeID))

        let avatarFetch = FetchDescriptor<AvatarLoadout>(
            predicate: #Predicate { $0.playerID == playerID })
        if let existing = (try? context.fetch(avatarFetch))?.first {
            avatarLoadout = existing
        } else {
            let fresh = AvatarLoadout(playerID: playerID)
            context.insert(fresh)
            avatarLoadout = fresh
        }

        let carFetch = FetchDescriptor<CarLoadout>(
            predicate: #Predicate { $0.playerID == playerID })
        if let existing = (try? context.fetch(carFetch))?.first {
            carLoadout = existing
        } else {
            let fresh = CarLoadout(playerID: playerID)
            context.insert(fresh)
            carLoadout = fresh
        }
        try? context.save()
    }

    // MARK: - Unlock gating

    func isUnlocked(_ item: CosmeticItem) -> Bool {
        guard let badgeID = item.unlockBadgeID else { return true }
        return earnedBadgeIDs.contains(badgeID)
    }

    // MARK: - Equip

    func equipHat(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.hats)) else { return }
        avatarLoadout.hatID = id
        save()
    }

    func equipAccessory(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.accessories)) else { return }
        avatarLoadout.accessoryID = id
        save()
    }

    func equipSticker(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.stickers)) else { return }
        avatarLoadout.stickerID = id
        save()
    }

    func equipCarColor(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.carColors)) else { return }
        carLoadout.colorID = id
        save()
    }

    func equipCarDecal(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.carDecals)) else { return }
        carLoadout.decalID = id
        save()
    }

    func equipCarAccessory(_ id: String) {
        guard isUnlocked(CosmeticCatalog.item(id, in: CosmeticCatalog.carAccessories)) else { return }
        carLoadout.accessoryID = id
        save()
    }

    // MARK: - Badges

    /// Awards a badge if it hasn't been earned yet. Idempotent — safe to
    /// call every time its condition is merely true, not just the instant
    /// it becomes true. Returns whether this call actually earned it.
    @discardableResult
    func award(_ badgeID: String) -> Bool {
        guard !earnedBadgeIDs.contains(badgeID) else { return false }
        earnedBadgeIDs.insert(badgeID)
        context.insert(EarnedBadge(playerID: playerID, badgeID: badgeID))
        save()
        celebrationQueue.append(badgeID)
        return true
    }

    func acknowledgeCelebration() {
        if !celebrationQueue.isEmpty {
            celebrationQueue.removeFirst()
        }
    }

    private func save() {
        try? context.save()
    }

    #if DEBUG
    /// -TTResetProgress: wipes this device's badges/cosmetics so a debug
    /// run can retrigger celebrations deterministically instead of finding
    /// everything already earned from a previous launch.
    func debugResetAll() {
        for badgeID in earnedBadgeIDs {
            let fetch = FetchDescriptor<EarnedBadge>(
                predicate: #Predicate { $0.playerID == playerID && $0.badgeID == badgeID })
            for row in (try? context.fetch(fetch)) ?? [] {
                context.delete(row)
            }
        }
        earnedBadgeIDs = []
        avatarLoadout.hatID = "hat-none"
        avatarLoadout.accessoryID = "acc-none"
        avatarLoadout.stickerID = "sticker-none"
        carLoadout.colorID = "car-cherry"
        carLoadout.decalID = "decal-none"
        carLoadout.accessoryID = "cartop-none"
        celebrationQueue = []
        save()
    }
    #endif
}
