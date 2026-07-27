//
//  GarageView.swift
//  Travel Trivia
//
//  My Garage: avatar customization + shop, a personal car customization
//  (distinct from "Our Ride", the shared seat-picker vehicle), and the
//  Badges collection that unlocks them. Everything here is local-only
//  SwiftData (ProgressStore) — never leaves the device.
//
//  DRAFT catalog: the specific cosmetic/badge list here is this session's
//  proposal, not a confirmed design spec — see CosmeticCatalog and
//  BadgeCatalog for the actual items, and the session report for the
//  flag Blake should review.
//

import SwiftUI

struct GarageView: View {
    @Environment(AppModel.self) private var app
    @State private var tab: Tab = .avatar

    private enum Tab: String, CaseIterable, Identifiable {
        case avatar = "AVATAR", car = "MY GARAGE", badges = "BADGES"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 12) {
            FlowHeader(title: "MY GARAGE", titleSize: 32) {
                app.route = .menu
            }
            .padding(.horizontal, 20)

            tabPicker

            ScrollView {
                Group {
                    switch tab {
                    case .avatar: avatarTab
                    case .car: carTab
                    case .badges: badgesTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.vertical, 10)
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { t in
                Button { tab = t } label: {
                    StickerChip(text: t.rawValue, fill: tab == t ? TT.signGreen : TT.paper,
                                textColor: tab == t ? .white : TT.ink, textSize: 12)
                }
                .buttonStyle(.bubble)
                .accessibilityIdentifier("garage-tab-\(t.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
            }
        }
    }

    // MARK: - Avatar tab

    private var avatarTab: some View {
        VStack(spacing: 18) {
            // Preview uses a fixed placeholder color: actual in-game body
            // color is assigned per party by the host (colorIndex), not a
            // My Garage customization — kept out of scope this session.
            AvatarFullBody(color: TT.avatarColors[0], expression: .happy, height: 150,
                           hatID: app.progress.avatarLoadout.hatID,
                           accessoryID: app.progress.avatarLoadout.accessoryID,
                           stickerID: app.progress.avatarLoadout.stickerID)
                .accessibilityIdentifier("garage-avatar-preview")

            cosmeticRow(title: "HAT", items: CosmeticCatalog.hats,
                        equipped: app.progress.avatarLoadout.hatID) { app.progress.equipHat($0) }
            cosmeticRow(title: "ACCESSORY", items: CosmeticCatalog.accessories,
                        equipped: app.progress.avatarLoadout.accessoryID) { app.progress.equipAccessory($0) }
            cosmeticRow(title: "CHEEK STICKER", items: CosmeticCatalog.stickers,
                        equipped: app.progress.avatarLoadout.stickerID) { app.progress.equipSticker($0) }
        }
    }

    // MARK: - My Garage car tab

    private var carTab: some View {
        VStack(spacing: 18) {
            MyGarageCarPreview(colorID: app.progress.carLoadout.colorID,
                               decalID: app.progress.carLoadout.decalID,
                               accessoryID: app.progress.carLoadout.accessoryID)
                .accessibilityIdentifier("garage-car-preview")
            StickerChip(text: "YOUR PERSONAL CAR — NOT \"OUR RIDE\"", fill: TT.grape,
                        textColor: .white, textSize: 10)

            cosmeticRow(title: "COLOR", items: CosmeticCatalog.carColors,
                        equipped: app.progress.carLoadout.colorID) { app.progress.equipCarColor($0) }
            cosmeticRow(title: "DECAL", items: CosmeticCatalog.carDecals,
                        equipped: app.progress.carLoadout.decalID) { app.progress.equipCarDecal($0) }
            cosmeticRow(title: "ROOF", items: CosmeticCatalog.carAccessories,
                        equipped: app.progress.carLoadout.accessoryID) { app.progress.equipCarAccessory($0) }
        }
    }

    // MARK: - Badges tab

    private var badgesTab: some View {
        let badges = BadgeCatalog.allBadges(catalog: app.catalog)
        return VStack(spacing: 10) {
            StickerChip(text: "\(app.progress.earnedBadgeIDs.count) / \(badges.count) EARNED",
                        fill: TT.sunshine, textSize: 12)
                .accessibilityIdentifier("badge-earned-count")
            ForEach(badges) { badge in
                let earned = app.progress.earnedBadgeIDs.contains(badge.id)
                HStack(spacing: 10) {
                    Image(systemName: earned ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(earned ? TT.lime : TT.ink.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge.title)
                            .font(TT.font(14, .heavy))
                            .foregroundStyle(TT.ink)
                        Text(badge.subtitle)
                            .font(TT.font(11, .bold))
                            .foregroundStyle(TT.ink.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(12)
                .opacity(earned ? 1 : 0.6)
                .sticker(RoundedRectangle(cornerRadius: 14), fill: TT.paper)
                .accessibilityIdentifier("badge-row-\(badge.id)")
            }
        }
    }

    // MARK: - Shared cosmetic row

    private func cosmeticRow(title: String, items: [CosmeticItem], equipped: String,
                             equip: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StickerChip(text: title, fill: TT.sunshine, textSize: 11)
            HStack(spacing: 10) {
                ForEach(items) { item in
                    cosmeticButton(item: item, isEquipped: item.id == equipped) { equip(item.id) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cosmeticButton(item: CosmeticItem, isEquipped: Bool, action: @escaping () -> Void) -> some View {
        let unlocked = app.progress.isUnlocked(item)
        return Button {
            if unlocked { action() }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Text(String(item.displayName.prefix(1)))
                        .font(TT.font(18, .black))
                        .foregroundStyle(unlocked ? (isEquipped ? .white : TT.ink) : TT.ink.opacity(0.3))
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TT.ink.opacity(0.55))
                    }
                }
                .frame(width: 52, height: 52)
                .sticker(RoundedRectangle(cornerRadius: 12), fill: isEquipped ? TT.signGreen : TT.paper)

                Text(item.displayName)
                    .font(TT.font(8, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 60)

                if !unlocked, let badgeID = item.unlockBadgeID,
                   let badge = BadgeCatalog.definition(for: badgeID, catalog: app.catalog) {
                    Text(badge.title.uppercased())
                        .font(TT.font(6.5, .black))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                }
            }
        }
        .buttonStyle(.bubble)
        .disabled(!unlocked)
        .opacity(unlocked ? 1 : 0.7)
        .accessibilityIdentifier("cosmetic-\(item.id)")
        // UI-test hook: lets tests confirm equip state round-trips (and
        // persists across relaunch) without needing pixel comparisons.
        .accessibilityValue(isEquipped ? "equipped" : (unlocked ? "unlocked" : "locked"))
    }
}

/// Simple top-down glyph for the personal "My Garage" car — visually
/// unrelated to the "Our Ride" seat-picker vehicle so the two never get
/// confused, per the design doc's explicit naming split.
private struct MyGarageCarPreview: View {
    var colorID: String
    var decalID: String
    var accessoryID: String

    private var color: Color {
        switch colorID {
        case "car-lime": TT.lime
        case "car-sunshine": TT.sunshine
        case "car-grape": TT.grape
        default: TT.cherry
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 40).stroke(TT.ink, lineWidth: 4))
                .frame(width: 160, height: 220)

            if decalID == "decal-flames" {
                Text("🔥").font(.system(size: 34)).offset(y: 30)
            } else if decalID == "decal-stars" {
                Text("⭐️⭐️").font(.system(size: 26)).offset(y: 30)
            }

            if accessoryID == "cartop-surfboard" {
                RoundedRectangle(cornerRadius: 10)
                    .fill(TT.sky)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(TT.ink, lineWidth: 3))
                    .frame(width: 24, height: 130)
                    .offset(y: -140)
            } else if accessoryID == "cartop-antenna" {
                Capsule()
                    .fill(TT.paper)
                    .overlay(Capsule().stroke(TT.ink, lineWidth: 2))
                    .frame(width: 34, height: 14)
                    .offset(x: 40, y: -122)
            }
        }
        .frame(height: 220)
    }
}
