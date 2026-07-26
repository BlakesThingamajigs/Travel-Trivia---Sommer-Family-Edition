//
//  BubbleButtonStyle.swift
//  Travel Trivia
//
//  Core interaction feel: every tappable element squishes on press and
//  springs back with an overshoot bounce on release. The press-in spring is
//  quick and controlled; the release spring is deliberately underdamped so
//  the button visibly wobbles past 1.0 before settling.
//

import SwiftUI

struct BubbleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.16, dampingFraction: 0.8)
                    : .spring(response: 0.34, dampingFraction: 0.42),
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == BubbleButtonStyle {
    /// The standard Travel Trivia squish-and-bounce button feel.
    static var bubble: BubbleButtonStyle { BubbleButtonStyle() }
}
