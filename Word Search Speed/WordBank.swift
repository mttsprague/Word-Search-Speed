//
//  WordBank.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

enum WordBank {
    static func words(for difficulty: Difficulty) -> [String] {
        let filename: String
        switch difficulty {
        case .easy: filename = "words_easy"
        case .medium: filename = "words_medium"
        case .hard: filename = "words_hard"
        }

        if let loaded = loadWordsFromBundle(named: filename), !loaded.isEmpty {
            return loaded
        }

        // Fallback list so the app still runs if files are missing.
        return [
            "APPLE","BRAVE","CLOUD","RIVER","MUSIC","HOUSE","WATER","LIGHT","STONE","NORTH",
            "PUZZLE","ORANGE","GALAXY","FROZEN","JUNGLE","VOYAGE","HARMONY","MYSTERY","WIZARD","SPARK",
            "POETRY","ROCKET","PLANET","CASTLE","FOREST","DRAGON","SUNSET","THUNDER","CRYSTAL","FIREWORK"
        ]
    }

    static func pickWords(
        difficulty: Difficulty,
        rng: inout some RandomNumberGenerator
    ) -> [String] {
        let list = words(for: difficulty)
        let filtered = list
            .map { $0.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.allSatisfy({ $0.isLetter }) }
            .filter { difficulty.wordLengthRange.contains($0.count) }

        let pool = filtered.isEmpty ? list : filtered
        return Array(pool.shuffled(using: &rng).prefix(difficulty.wordCount))
    }

    private static func loadWordsFromBundle(named name: String) -> [String]? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return nil }
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
