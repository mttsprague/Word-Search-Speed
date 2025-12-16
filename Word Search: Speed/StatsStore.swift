//
//  StatsStore.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

final class StatsStore {
    static let shared = StatsStore()
    private init() {}

    private let defaults = UserDefaults.standard

    private enum K {
        static let gamesPlayed = "gamesPlayed"
        static let wins = "wins"
        static let bestSolveSeconds = "bestSolveSeconds" // lower is better
        static let streak = "streak"
        static let lastWinDay = "lastWinDay" // yyyy-MM-dd
    }

    var gamesPlayed: Int { defaults.integer(forKey: K.gamesPlayed) }
    var wins: Int { defaults.integer(forKey: K.wins) }
    var streak: Int { defaults.integer(forKey: K.streak) }

    var bestSolveSeconds: Int? {
        let v = defaults.integer(forKey: K.bestSolveSeconds)
        return v == 0 ? nil : v
    }

    func recordGamePlayed() {
        defaults.set(gamesPlayed + 1, forKey: K.gamesPlayed)
    }

    func recordWin(solveSeconds: Int) {
        defaults.set(wins + 1, forKey: K.wins)
        updateBestSolveIfNeeded(solveSeconds)

        let today = Self.dayString(Date())
        let last = defaults.string(forKey: K.lastWinDay)

        if last == today {
            // already counted today
        } else if let last, Self.isYesterday(dayString: last, comparedTo: today) {
            defaults.set(streak + 1, forKey: K.streak)
        } else {
            defaults.set(1, forKey: K.streak)
        }

        defaults.set(today, forKey: K.lastWinDay)
    }

    func recordLoss() {
        // optionally reset streak on loss; most games don't.
        // If you want streak-per-day only, keep it as-is.
    }

    private func updateBestSolveIfNeeded(_ solveSeconds: Int) {
        if let best = bestSolveSeconds {
            if solveSeconds < best {
                defaults.set(solveSeconds, forKey: K.bestSolveSeconds)
            }
        } else {
            defaults.set(solveSeconds, forKey: K.bestSolveSeconds)
        }
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func isYesterday(dayString: String, comparedTo todayString: String) -> Bool {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        guard let d1 = f.date(from: dayString),
              let d2 = f.date(from: todayString) else { return false }
        return Calendar.current.dateComponents([.day], from: d1, to: d2).day == 1
    }
}
