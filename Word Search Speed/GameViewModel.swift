//
//  GameViewModel.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    @Published var difficulty: Difficulty = .easy
    @Published var puzzle: Puzzle = Puzzle(size: 10, grid: [], words: [])
    @Published var timeLeft: Int = 30
    @Published var phase: Phase = .playing

    @Published var selectedPath: [GridPoint] = []

    @Published var roundsCompleted: Int = 0
    @Published var rewardedUsedThisRound: Bool = false

    // Score
    @Published var totalScore: Int = 0
    @Published var lastRoundScore: Int = 0
    @Published var lastRoundBreakdown: ScoreBreakdown = .empty

    // Difficulty selection sheet control
    @Published var needsDifficultySelection: Bool = false

    enum Phase { case playing, won, lost }

    struct ScoreBreakdown: Equatable {
        let wordsFound: Int
        let wordPoints: Int
        let timeLeftUsedForScoring: Int
        let difficultyMultiplier: Int
        let timeBonus: Int
        let rewardedPenaltyApplied: Bool

        var roundScore: Int { wordPoints + timeBonus }

        static let empty = ScoreBreakdown(
            wordsFound: 0,
            wordPoints: 0,
            timeLeftUsedForScoring: 0,
            difficultyMultiplier: 1,
            timeBonus: 0,
            rewardedPenaltyApplied: false
        )
    }

    private let engine = PuzzleEngine()
    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()

    private var dragStart: GridPoint?

    private var roundStartTime: Date?
    private let stats = StatsStore.shared

    // Prevents resetting the round when the view reappears (e.g., after a full-screen ad).
    private var didStart = false

    private let defaults = UserDefaults.standard
    private enum K {
        static let selectedDifficulty = "selectedDifficulty"
    }

    // Prevent double score finalization for a round
    private var scoreFinalizedForCurrentRound = false

    // Scoring constants
    private let basePerWord = 100
    private func multiplier(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }

    func start() {
        // Make this idempotent so .onAppear doesn’t start a new round again after ads.
        guard didStart == false else { return }
        didStart = true

        // Do NOT preload ads here anymore; AppDelegate preloads after consent.
        // If you want a safety net in case AppDelegate didn’t preload (e.g., dev builds), you could:
        // if ConsentManager.shared.canRequestAds { AdManager.shared.preloadAll() }

        // Load persisted difficulty if available. If not, prompt selection.
        if let saved = defaults.string(forKey: K.selectedDifficulty),
           let d = Self.deserializeDifficulty(saved) {
            difficulty = d
            // First game in a session: reset score
            newRound(resetScore: true)
        } else {
            needsDifficultySelection = true
        }
    }

    // Call when the user picks a difficulty in the sheet.
    func applyDifficulty(_ newDifficulty: Difficulty) {
        difficulty = newDifficulty
        defaults.set(Self.serializeDifficulty(newDifficulty), forKey: K.selectedDifficulty)
        needsDifficultySelection = false
        // Changing difficulty starts a new game: reset score
        newRound(resetScore: true)
    }

    func newRound(resetScore: Bool = false) {
        timer?.invalidate()

        if resetScore {
            totalScore = 0
        }

        let words = WordBank.pickWords(difficulty: difficulty, rng: &rng)
        puzzle = engine.makePuzzle(
            size: difficulty.gridSize,
            words: words,
            allowedDirections: difficulty.allowedDirections,
            rng: &rng
        )

        timeLeft = difficulty.seconds
        phase = .playing
        selectedPath = []
        dragStart = nil
        rewardedUsedThisRound = false
        roundStartTime = Date()
        scoreFinalizedForCurrentRound = false
        lastRoundScore = 0
        lastRoundBreakdown = .empty

        stats.recordGamePlayed()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.phase == .playing else { return }
                self.timeLeft -= 1
                if self.timeLeft <= 0 {
                    // Timer ran out: reset cumulative score immediately
                    self.totalScore = 0
                    self.phase = .lost
                    self.timer?.invalidate()
                    // Do NOT finalize score here; user may continue with rewarded.
                }
            }
        }
    }

    // MARK: - Pause/Resume timer for overlays/sheets

    func pauseTimer() {
        timer?.invalidate()
    }

    func resumeTimer() {
        guard phase == .playing else { return }
        startTimerAgain()
    }

    // MARK: - Round transitions + Interstitial pacing

    func nextPuzzleTapped() {
        // If the round ended in a loss and the user did not continue, finalize score now.
        if phase == .lost && scoreFinalizedForCurrentRound == false {
            finalizeRoundScore()
        }

        roundsCompleted += 1

        // Interstitial every 3 rounds, between puzzles only
        if roundsCompleted % 3 == 0 {
            AdManager.shared.showInterstitialIfReady()
        }

        // If we are advancing after a loss, that starts a new game: reset score.
        let shouldReset = (phase == .lost)
        newRound(resetScore: shouldReset)
    }

    // MARK: - Rewarded continue

    func continueWithRewarded() {
        guard phase == .lost else { return }
        guard rewardedUsedThisRound == false else { return }

        AdManager.shared.showRewarded { [weak self] earned in
            guard let self else { return }
            guard earned else { return }
            Task { @MainActor in
                // Continue the same puzzle:
                self.rewardedUsedThisRound = true
                self.phase = .playing
                // Give them +15s play window; this does not inflate score (soft penalty applied later)
                self.timeLeft = 15
                self.startTimerAgain()
            }
        }
    }

    private func startTimerAgain() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.phase == .playing else { return }
                self.timeLeft -= 1
                if self.timeLeft <= 0 {
                    // Timer ran out again: reset cumulative score immediately
                    self.totalScore = 0
                    self.phase = .lost
                    self.timer?.invalidate()
                    // Still do not finalize here; allow user to choose next or continue.
                }
            }
        }
    }

    // MARK: - Drag selection

    func dragChanged(at point: GridPoint?) {
        guard phase == .playing else { return }
        guard let p = point else { return }

        if dragStart == nil {
            dragStart = p
            selectedPath = [p]
            return
        }

        guard let start = dragStart else { return }
        selectedPath = computeLineSelection(from: start, to: p, gridSize: puzzle.size)
    }

    func dragEnded() {
        guard phase == .playing else {
            dragStart = nil
            selectedPath = []
            return
        }

        defer {
            dragStart = nil
            selectedPath = []
        }

        let s = selectedPathString()
        guard !s.isEmpty else { return }

        var justFoundAWord = false

        for i in puzzle.words.indices {
            guard puzzle.words[i].found == false else { continue }
            let target = puzzle.words[i].word

            if difficulty.allowBackwards {
                if s == target || String(s.reversed()) == target {
                    puzzle.words[i].found = true
                    justFoundAWord = true
                    break
                }
            } else {
                if s == target {
                    puzzle.words[i].found = true
                    justFoundAWord = true
                    break
                }
            }
        }

        // Add 5 seconds to the clock whenever a word is found
        if justFoundAWord {
            timeLeft += 5
        }

        if !puzzle.words.isEmpty && puzzle.words.allSatisfy({ $0.found }) {
            phase = .won
            timer?.invalidate()

            // record solve time
            if let start = roundStartTime {
                let solveSeconds = max(0, Int(Date().timeIntervalSince(start)))
                stats.recordWin(solveSeconds: solveSeconds)
            }

            // Finalize score immediately on win
            finalizeRoundScore()
        }
    }

    private func selectedPathString() -> String {
        guard !puzzle.grid.isEmpty else { return "" }
        var chars: [Character] = []
        for p in selectedPath {
            guard p.r >= 0, p.r < puzzle.size, p.c >= 0, p.c < puzzle.size else { continue }
            chars.append(puzzle.grid[p.r][p.c])
        }
        return String(chars)
    }

    private func computeLineSelection(from a: GridPoint, to b: GridPoint, gridSize: Int) -> [GridPoint] {
        let dr = b.r - a.r
        let dc = b.c - a.c
        let adr = abs(dr), adc = abs(dc)

        let step: (Int, Int)?
        if dr == 0 && dc != 0 { step = (0, dc > 0 ? 1 : -1) }
        else if dc == 0 && dr != 0 { step = (dr > 0 ? 1 : -1, 0) }
        else if adr == adc && adr != 0 { step = (dr > 0 ? 1 : -1, dc > 0 ? 1 : -1) }
        else { step = nil }

        guard let s = step else { return [a] }

        var pts: [GridPoint] = []
        var r = a.r
        var c = a.c
        pts.append(GridPoint(r: r, c: c))

        while r != b.r || c != b.c {
            r += s.0
            c += s.1
            if r < 0 || r >= gridSize || c < 0 || c >= gridSize { break }
            pts.append(GridPoint(r: r, c: c))
        }
        return pts
    }

    // MARK: - Highlights

    func isSelected(_ p: GridPoint) -> Bool {
        selectedPath.contains(p)
    }

    func isFoundCell(_ p: GridPoint) -> Bool {
        puzzle.words.contains(where: { $0.found && $0.path.contains(p) })
    }

    // MARK: - Scoring

    private func finalizeRoundScore() {
        guard scoreFinalizedForCurrentRound == false else { return }
        scoreFinalizedForCurrentRound = true

        let wordsFound = puzzle.words.filter { $0.found }.count
        let wordPoints = wordsFound * basePerWord

        // Soft penalty: if rewarded was used, subtract 15s from time used for scoring (never below 0)
        let timeLeftForScoring = max(0, timeLeft - (rewardedUsedThisRound ? 15 : 0))
        let mult = multiplier(for: difficulty)
        let timeBonus = timeLeftForScoring * mult

        let breakdown = ScoreBreakdown(
            wordsFound: wordsFound,
            wordPoints: wordPoints,
            timeLeftUsedForScoring: timeLeftForScoring,
            difficultyMultiplier: mult,
            timeBonus: timeBonus,
            rewardedPenaltyApplied: rewardedUsedThisRound
        )

        lastRoundBreakdown = breakdown
        lastRoundScore = breakdown.roundScore
        totalScore += breakdown.roundScore

        // Submit to Game Center
        GameCenterManager.shared.submit(score: breakdown.roundScore)
    }

    // MARK: - Persistence helpers

    private static func serializeDifficulty(_ d: Difficulty) -> String {
        switch d {
        case .easy: return "easy"
        case .medium: return "medium"
        case .hard: return "hard"
        }
    }

    private static func deserializeDifficulty(_ s: String) -> Difficulty? {
        switch s {
        case "easy": return .easy
        case "medium": return .medium
        case "hard": return .hard
        default: return nil
        }
    }
}

