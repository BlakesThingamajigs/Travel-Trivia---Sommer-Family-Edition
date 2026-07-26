//
//  SupabaseService.swift
//  Travel Trivia
//
//  Stubbed this session: no auth flows or table reads are wired into the
//  UI yet. The client exists so later sessions have real infrastructure to
//  build on (Google/Apple sign-in, question sync).
//
//  Secrets come from an untracked `Supabase.xcconfig.local` bundled config
//  (matches the .gitignore's existing `*.xcconfig.local` pattern). Copy
//  `Supabase.xcconfig.example` next to it, fill in the real values, and the
//  client lights up; without it the app runs fine on local seed content.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let projectURL: URL? = values["SUPABASE_URL"].flatMap(URL.init(string:))
    static let anonKey: String? = values["SUPABASE_ANON_KEY"]

    /// Parses simple `KEY = VALUE` xcconfig lines from the bundled local
    /// config, if Blake has supplied one.
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Supabase.xcconfig", withExtension: "local"),
              let contents = try? String(contentsOf: url, encoding: .utf8)
        else { return [:] }

        var parsed: [String: String] = [:]
        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<equals]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty { parsed[key] = value }
        }
        return parsed
    }()
}

enum SupabaseService {
    /// Nil until real credentials are supplied via the local config file.
    static let client: SupabaseClient? = {
        guard let url = SupabaseConfig.projectURL, let key = SupabaseConfig.anonKey else {
            return nil
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: key)
    }()
}
