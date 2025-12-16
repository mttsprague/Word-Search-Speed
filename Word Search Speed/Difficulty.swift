//
//  Difficulty.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

enum Difficulty: CaseIterable, Hashable {
    case easy, medium, hard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var gridSize: Int {
        switch self {
        case .easy: return 10
        case .medium: return 12
        case .hard: return 14
        }
    }

    // Use 3 words for all difficulties
    var wordCount: Int { 3 }

    var seconds: Int { 30 }

    var wordLengthRange: ClosedRange<Int> {
        switch self {
        case .easy: return 4...6
        case .medium: return 6...8
        case .hard: return 8...10
        }
    }

    // Easy: no backwards selection/match
    var allowBackwards: Bool {
        switch self {
        case .easy: return false
        case .medium, .hard: return true
        }
    }

    // Easy: diagonal ok, but no “backwards spelling” placements (no left/up/up-diagonals)
    var allowedDirections: [(dr: Int, dc: Int)] {
        switch self {
        case .easy:
            // Right, Down, Down-Right, Down-Left
            return [(0,1), (1,0), (1,1), (1,-1)]
        case .medium, .hard:
            // All 8 directions
            return [(0,1),(1,0),(0,-1),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)]
        }
    }
}

