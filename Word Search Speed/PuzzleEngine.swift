//
//  PuzzleEngine.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

final class PuzzleEngine {

    func makePuzzle(
        size: Int,
        words: [String],
        allowedDirections: [(dr: Int, dc: Int)],
        rng: inout some RandomNumberGenerator
    ) -> Puzzle {
        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [PlacedWord] = []

        for w in words {
            if let pw = place(word: w, in: &grid, size: size, allowedDirections: allowedDirections, rng: &rng) {
                placed.append(pw)
            }
        }

        for r in 0..<size {
            for c in 0..<size where grid[r][c] == " " {
                grid[r][c] = weightedLetter(using: &rng)
            }
        }

        return Puzzle(size: size, grid: grid, words: placed)
    }

    private func place(
        word: String,
        in grid: inout [[Character]],
        size: Int,
        allowedDirections: [(dr: Int, dc: Int)],
        rng: inout some RandomNumberGenerator
    ) -> PlacedWord? {
        let upper = word.uppercased()
        let letters = Array(upper)
        let len = letters.count

        for _ in 0..<400 {
            let dir = allowedDirections.randomElement(using: &rng)!
            let (dr, dc) = (dir.dr, dir.dc)

            func startRange(_ d: Int) -> ClosedRange<Int> {
                if d == 0 { return 0...(size - 1) }
                if d > 0 { return 0...(size - len) }
                return (len - 1)...(size - 1)
            }

            let r0 = Int.random(in: startRange(dr), using: &rng)
            let c0 = Int.random(in: startRange(dc), using: &rng)

            var path: [GridPoint] = []
            var ok = true

            for i in 0..<len {
                let r = r0 + i * dr
                let c = c0 + i * dc
                let existing = grid[r][c]
                let ch = letters[i]
                if existing != " " && existing != ch { ok = false; break }
                path.append(GridPoint(r: r, c: c))
            }

            guard ok else { continue }

            for (i, p) in path.enumerated() {
                grid[p.r][p.c] = letters[i]
            }

            return PlacedWord(word: upper, path: path, found: false)
        }

        return nil
    }

    private func weightedLetter(using rng: inout some RandomNumberGenerator) -> Character {
        let letters = Array("EEEEEEEEEEEEAAAAAAAAAIIIIIIIIIIOOOOOOOONNNNNNRRRRRRTTTTTLLLLSSSSUUUUDDDDGGGBBCCMMPPFFHHVVWWYYKJXQZ")
        return letters.randomElement(using: &rng)!
    }
}
