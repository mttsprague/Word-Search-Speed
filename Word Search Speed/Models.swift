//
//  Models.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

struct GridPoint: Hashable {
    let r: Int
    let c: Int
}

struct PlacedWord: Identifiable {
    let id = UUID()
    let word: String
    let path: [GridPoint]
    var found: Bool = false
}

struct Puzzle {
    let size: Int
    let grid: [[Character]]
    var words: [PlacedWord]
}

