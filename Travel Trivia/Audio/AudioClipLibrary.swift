//
//  AudioClipLibrary.swift
//  Travel Trivia
//
//  Resolves a question's bundled audio clip. Clips live under
//  Travel Trivia/AudioClips/<genre-slug>/<file>.m4a — that whole tree is
//  auto-bundled by Xcode's file-system-synchronized group, so no asset
//  catalog or manifest is needed at build time; this just knows the
//  folder-naming convention.
//
//  Live Supabase rows point `media_url` at the same bundle-relative path
//  (e.g. "animal-sounds-safari/cow.m4a") rather than a streamable remote
//  URL, because AVFoundation on iOS can't decode the raw Ogg Vorbis the
//  source clips originally shipped as — see AudioSeedQuestions.swift for
//  why. The starter pack is genuinely local-first either way, consistent
//  with the "bundled starter pack per audio genre" offline-resilience
//  decision in the design vault.
//

import Foundation

nonisolated enum AudioClipLibrary {
    /// nil if the clip isn't bundled (offline gap, bad filename, etc.) —
    /// callers should treat that as "skip audio, show text only".
    ///
    /// Xcode's file-system-synchronized groups (this project uses them for
    /// the whole "Travel Trivia" folder) flatten nested resource folders
    /// into the bundle root rather than preserving them as folder
    /// references — confirmed by inspecting a real build product, not
    /// assumed. Every bundled clip filename is unique across all 3 audio
    /// genres, so a flat lookup is safe; the subdirectory is tried first
    /// anyway in case that flattening behavior ever changes.
    static func url(genreSlug: String, fileName: String) -> URL? {
        let base = fileName.replacingOccurrences(of: ".m4a", with: "")
        if let nested = Bundle.main.url(forResource: base, withExtension: "m4a",
                                         subdirectory: "AudioClips/\(genreSlug)") {
            return nested
        }
        return Bundle.main.url(forResource: base, withExtension: "m4a")
    }

    static func url(for question: TriviaQuestion, genreSlug: String) -> URL? {
        guard let fileName = question.mediaFileName else { return nil }
        return url(genreSlug: genreSlug, fileName: fileName)
    }
}
