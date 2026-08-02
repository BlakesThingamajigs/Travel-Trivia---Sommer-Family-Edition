//
//  StickerControls.swift
//  Travel Trivia
//
//  Form controls in the sticker language: text fields, toggles, and the
//  round back/utility bubble buttons the menu screens share.
//

import SwiftUI

/// Text entry on a paper sticker card.
struct StickerTextField: View {
    var label: String
    @Binding var text: String
    var prompt: String = ""
    var keyboard: UIKeyboardType = .default
    var maxLength: Int = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StickerChip(text: label.uppercased(), fill: TT.sunshine, textSize: 11)
            TextField(prompt, text: $text)
                .font(TT.font(19, .heavy))
                .foregroundStyle(TT.ink)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .sticker(RoundedRectangle(cornerRadius: 14), fill: TT.paper)
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
    }
}

/// Chunky sticker switch: asphalt track, paper knob, lime when on.
struct StickerToggle: View {
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack {
                Text(label)
                    .font(TT.font(16, .heavy))
                    .foregroundStyle(TT.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 12)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? TT.lime : TT.asphalt)
                        .overlay(Capsule().stroke(TT.ink, lineWidth: 3))
                        .frame(width: 62, height: 34)
                    Circle()
                        .fill(TT.paper)
                        .overlay(Circle().stroke(TT.ink, lineWidth: 2.5))
                        .frame(width: 26, height: 26)
                        .padding(4)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isOn)
            }
            .padding(14)
            .sticker(RoundedRectangle(cornerRadius: 16), fill: TT.paper)
        }
        .buttonStyle(.bubble)
        .accessibilityValue(isOn ? "on" : "off")
    }
}

/// Round utility button (back chevron, gear, dice…) in a sticker circle.
struct BubbleIconButton: View {
    var systemName: String
    var fill: Color = TT.sunshine
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(TT.ink)
                .frame(width: 44, height: 44)
                .sticker(Circle(), fill: fill, lineWidth: 3, drop: CGSize(width: 0, height: 4))
        }
        .buttonStyle(.bubble)
    }
}

/// Shared header for the setup screens: back bubble + sticker title.
struct FlowHeader: View {
    var title: String
    var titleSize: CGFloat = 34
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            StickerText(text: title, size: titleSize)
            if let onBack {
                HStack {
                    BubbleIconButton(systemName: "chevron.left", fill: TT.paper, action: onBack)
                        .accessibilityIdentifier("flow-back")
                    Spacer()
                }
            }
        }
        .padding(.top, 6)
    }
}
