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
    /// Nil for prediction-style questions (Would You Rather): there is no
    /// authored answer — whichever option wins the party's vote becomes
    /// correct at resolution time.
    let correctOptionID: String?

    var isMajorityScored: Bool { correctOptionID == nil }

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

/// The "majority vote becomes correct" resolver behind Would You Rather —
/// deliberately genre/mode-agnostic so Herd Reveal can reuse it as-is.
nonisolated enum MajorityVote {
    /// The option that received the most votes; ties break toward the
    /// earlier option in display order so every device agrees. Nil when
    /// nobody voted.
    static func winningOptionID(votes: some Sequence<String>, options: [AnswerOption]) -> String? {
        var counts: [String: Int] = [:]
        for vote in votes { counts[vote, default: 0] += 1 }
        var winner: (id: String, count: Int)?
        for option in options {
            if let count = counts[option.id], count > (winner?.count ?? 0) {
                winner = (option.id, count)
            }
        }
        return winner?.id
    }
}
