//
//  GameViewModel.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {
    @Published var difficulty: Difficulty = .easy
    @Published var puzzle: Puzzle = Puzzle(size: 10, grid: [], words: [])
    @Published var timeLeft: Int = 30
    @Published var phase: Phase = .playing

    @Published var selectedPath: [GridPoint] = []

    @Published var roundsCompleted: Int = 0
    @Published var rewardedUsedThisRound: Bool = false

    enum Phase { case playing, won, lost }

    private let engine = PuzzleEngine()
    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()

    private var dragStart: GridPoint?

    private var roundStartTime: Date?
    private let stats = StatsStore.shared

    func start() {
        AdManager.shared.preloadAll()
        newRound()
    }

    func newRound() {
        timer?.invalidate()

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

        stats.recordGamePlayed()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.phase == .playing else { return }
            self.timeLeft -= 1
            if self.timeLeft <= 0 {
                self.phase = .lost
                self.timer?.invalidate()
            }
        }
    }

    // MARK: - Round transitions + Interstitial pacing

    func nextPuzzleTapped() {
        roundsCompleted += 1

        // Interstitial every 3 rounds, between puzzles only
        if roundsCompleted % 3 == 0 {
            AdManager.shared.showInterstitialIfReady()
        }

        newRound()
    }

    // MARK: - Rewarded continue

    func continueWithRewarded() {
        guard phase == .lost else { return }
        guard rewardedUsedThisRound == false else { return }

        AdManager.shared.showRewarded { [weak self] earned in
            guard let self else { return }
            guard earned else { return }
            // Continue the same puzzle:
            self.rewardedUsedThisRound = true
            self.phase = .playing
            self.timeLeft = 10 // give them a small window; tweak if you want
            self.startTimerAgain()
        }
    }

    private func startTimerAgain() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.phase == .playing else { return }
            self.timeLeft -= 1
            if self.timeLeft <= 0 {
                self.phase = .lost
                self.timer?.invalidate()
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

        for i in puzzle.words.indices {
            guard puzzle.words[i].found == false else { continue }
            let target = puzzle.words[i].word

            if difficulty.allowBackwards {
                if s == target || String(s.reversed()) == target {
                    puzzle.words[i].found = true
                    break
                }
            } else {
                if s == target {
                    puzzle.words[i].found = true
                    break
                }
            }
        }

        if !puzzle.words.isEmpty && puzzle.words.allSatisfy({ $0.found }) {
            phase = .won
            timer?.invalidate()

            // record solve time
            if let start = roundStartTime {
                let solveSeconds = max(0, Int(Date().timeIntervalSince(start)))
                stats.recordWin(solveSeconds: solveSeconds)
            }
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
}
