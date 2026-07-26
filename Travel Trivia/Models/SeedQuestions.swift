//
//  SeedQuestions.swift
//  Travel Trivia
//
//  The 16 Riddle Realm seed questions. The same content is seeded into the
//  Supabase `questions` table (see supabase/migrations); this local copy is
//  the offline starter pack the slice plays from.
//

import Foundation

enum SeedQuestions {
    static let riddleRealm: [TriviaQuestion] = {
        func question(_ number: Int, _ difficulty: Difficulty, _ prompt: String,
                      _ optionTexts: [String]) -> TriviaQuestion {
            // First authored option is always the correct one; display order
            // is shuffled at game start.
            let options = optionTexts.enumerated().map { index, text in
                AnswerOption(id: "riddle-\(number)-\(index)", text: text)
            }
            return TriviaQuestion(
                id: "riddle-\(number)",
                difficulty: difficulty,
                prompt: prompt,
                options: options,
                correctOptionID: options[0].id
            )
        }

        return [
            question(1, .easy, "I have keys but no locks, space but no room — you can enter, but not go outside. What am I?",
                     ["Keyboard", "House", "Piano", "Map", "Wallet", "Elevator"]),
            question(2, .easy, "What has hands but can't clap?",
                     ["Clock", "Glove", "Statue", "Robot", "Watch", "Mannequin"]),
            question(3, .easy, "What has a neck but no head?",
                     ["Bottle", "Shirt", "Guitar", "Turtle", "Violin", "Sweater"]),
            question(4, .easy, "What gets wetter the more it dries?",
                     ["Towel", "Sponge", "Rain", "Ocean", "Washcloth", "Umbrella"]),
            question(5, .easy, "What has to be broken before you can use it?",
                     ["Egg", "Promise", "Record", "Seal", "Piggy Bank", "Code"]),
            question(6, .easy, "What has one eye but can't see?",
                     ["Needle", "Storm", "Potato", "Cat", "Hurricane", "Button"]),
            question(7, .medium, "I speak without a mouth, hear without ears, and come alive with the wind. What am I?",
                     ["Echo", "Ghost", "Shadow", "Whisper", "Wind", "Radio"]),
            question(8, .medium, "What comes once in a minute, twice in a moment, but never in a thousand years?",
                     ["Letter M", "Heartbeat", "Blink", "Second", "Letter N", "Minute Hand"]),
            question(9, .medium, "I'm tall when I'm young and short when I'm old. What am I?",
                     ["Candle", "Tree", "Person", "Pencil", "Match", "Crayon"]),
            question(10, .medium, "What can travel around the world while staying in a corner?",
                     ["Stamp", "Map", "Globe", "Coin", "Postcard", "Sticker"]),
            question(11, .medium, "What building has the most stories?",
                     ["Library", "Skyscraper", "Museum", "School", "Bookstore", "Apartment"]),
            question(12, .medium, "What's full of holes but still holds water?",
                     ["Sponge", "Net", "Colander", "Cloud", "Sieve", "Screen"]),
            question(13, .hard, "I'm not alive, but I grow. I don't have lungs, but I need air. I don't have a mouth, but water kills me. What am I?",
                     ["Fire", "Plant", "Cloud", "Ice", "Smoke", "Steam"]),
            question(14, .hard, "What has many teeth but cannot bite?",
                     ["Comb", "Saw", "Zipper", "Gear", "Rake", "Fork"]),
            question(15, .hard, "I shave every day, but my beard stays the same. What am I?",
                     ["Barber", "Werewolf", "Goat", "Father Time", "Lumberjack", "Santa"]),
            question(16, .hard, "The more you take, the more you leave behind. What am I?",
                     ["Footsteps", "Time", "Memories", "Breath", "Shadow", "Age"]),
        ]
    }()
}
