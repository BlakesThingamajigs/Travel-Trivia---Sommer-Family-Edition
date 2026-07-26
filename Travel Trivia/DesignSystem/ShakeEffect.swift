//
//  ShakeEffect.swift
//  Travel Trivia
//

import SwiftUI

nonisolated struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var shakes: CGFloat = 4
    var amplitude: CGFloat = 9

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let x = sin(travel * .pi * shakes * 2) * amplitude * (1 - travel)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct ShakeTriggerModifier: ViewModifier {
    let trigger: Int
    @State private var travel: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(travel: travel))
            .onChange(of: trigger) { _, _ in
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { travel = 0 }
                withAnimation(.linear(duration: 0.5)) { travel = 1 }
            }
    }
}

extension View {
    /// Shakes the view horizontally whenever `trigger` changes.
    func shake(trigger: Int) -> some View {
        modifier(ShakeTriggerModifier(trigger: trigger))
    }
}
