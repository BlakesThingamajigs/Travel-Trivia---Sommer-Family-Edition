//
//  TriviaQuestion.swift
//  Travel Trivia
//
//  Mirrors the Supabase `questions` schema (options as {id, text} with a
//  correct_option_id, so display order can shuffle safely).
//

import Foundation

nonisolated enum Difficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard

    var displayName: String { rawValue.uppercased() }
}

nonisolated struct AnswerOption: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: String
    let text: String
}

// Codable so the host can ship the dealt question deck to every device in
// one party-state broadcast.
nonisolated struct TriviaQuestion: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let difficulty: Difficulty
    let prompt: String
    let options: [AnswerOption]
    let correctOptionID: String

    /// Copy with display order shuffled; correctness follows the option id.
    func shufflingOptions(using generator: inout some RandomNumberGenerator) -> TriviaQuestion {
        TriviaQuestion(
            id: id,
            difficulty: difficulty,
            prompt: prompt,
            options: options.shuffled(using: &generator),
            correctOptionID: correctOptionID
        )
    }
}
