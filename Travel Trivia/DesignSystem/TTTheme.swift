//
//  TTTheme.swift
//  Travel Trivia
//
//  Comic/sticker design language: bold saturated flat fills, thick ink
//  outlines, sticker-style offset borders. No gradients, no soft shadows.
//

import SwiftUI

enum TT {
    // MARK: Palette

    static let ink = Color(red: 0.12, green: 0.09, blue: 0.20)        // outlines everywhere
    static let paper = Color(red: 1.00, green: 0.97, blue: 0.88)      // card/plate fill
    static let sky = Color(red: 0.20, green: 0.71, blue: 0.92)        // app background
    static let skyDeep = Color(red: 0.12, green: 0.55, blue: 0.80)
    static let sunshine = Color(red: 1.00, green: 0.78, blue: 0.19)
    static let tangerine = Color(red: 1.00, green: 0.52, blue: 0.15)
    static let cherry = Color(red: 0.96, green: 0.24, blue: 0.31)     // wrong answers / strikes
    static let lime = Color(red: 0.36, green: 0.80, blue: 0.20)       // correct answers
    static let grape = Color(red: 0.58, green: 0.28, blue: 0.92)
    static let bubblegum = Color(red: 1.00, green: 0.38, blue: 0.63)
    static let asphalt = Color(red: 0.26, green: 0.28, blue: 0.36)    // road / seats
    static let signGreen = Color(red: 0.02, green: 0.58, blue: 0.35)  // highway signs

    /// Fixed color-per-grid-position for the 6 answer buttons. Order never
    /// changes between questions: the driver calls answers out by color +
    /// position, so both must stay unambiguous — which also rules out sky
    /// blue here (it would vanish into the background).
    static let answerColors: [Color] = [sunshine, bubblegum, lime, tangerine, grape, paper]

    static let avatarColors: [Color] = [tangerine, grape, lime, bubblegum, sunshine, cherry]

    // MARK: Type

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
