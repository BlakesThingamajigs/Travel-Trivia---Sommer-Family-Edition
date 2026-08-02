//
//  QuestionCountControl.swift
//  Travel Trivia
//
//  Host-facing round-length control: a slider from 5 to 50, plus the
//  current number is tappable for direct text entry. Shared by
//  CreateGameFlow and PlayAnotherRoundView rather than each building its
//  own — see PartyConfig.questionCount / QuestionDeck.deal for where the
//  number actually lands.
//

import SwiftUI

enum QuestionCountRange {
    static let bounds = 5...50

    /// Clamps a typed or slider value into 5...50 — shared by the slider
    /// binding and the tap-to-edit text field so both paths reject the
    /// same way instead of each guarding independently.
    static func clamp(_ value: Int) -> Int {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}

struct QuestionCountControl: View {
    @Binding var count: Int
    @State private var isEditingText = false
    @State private var textValue = ""
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StickerChip(text: "QUESTIONS PER ROUND", fill: TT.sunshine, textSize: 11)
            HStack(spacing: 12) {
                if isEditingText {
                    TextField("", text: $textValue)
                        .keyboardType(.numberPad)
                        .font(TT.font(22, .black))
                        .foregroundStyle(TT.ink)
                        .multilineTextAlignment(.center)
                        .frame(width: 64)
                        .padding(.vertical, 6)
                        .sticker(RoundedRectangle(cornerRadius: 10), fill: TT.paper)
                        .focused($textFieldFocused)
                        .accessibilityIdentifier("question-count-text-field")
                        .onSubmit(commitTextValue)
                        .onChange(of: textFieldFocused) { _, focused in
                            if !focused { commitTextValue() }
                        }
                } else {
                    Button {
                        textValue = String(count)
                        isEditingText = true
                        textFieldFocused = true
                    } label: {
                        Text("\(count)")
                            .font(TT.font(22, .black))
                            .foregroundStyle(TT.ink)
                            .frame(width: 64)
                            .padding(.vertical, 6)
                            .sticker(RoundedRectangle(cornerRadius: 10), fill: TT.paper)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("question-count-value")
                }

                Slider(
                    value: Binding(
                        get: { Double(count) },
                        set: { count = QuestionCountRange.clamp(Int($0.rounded())) }
                    ),
                    in: Double(QuestionCountRange.bounds.lowerBound)...Double(QuestionCountRange.bounds.upperBound),
                    step: 1
                )
                .tint(TT.grape)
                .accessibilityIdentifier("question-count-slider")
            }
        }
    }

    private func commitTextValue() {
        isEditingText = false
        guard let typed = Int(textValue.trimmingCharacters(in: .whitespaces)) else { return }
        count = QuestionCountRange.clamp(typed)
    }
}
