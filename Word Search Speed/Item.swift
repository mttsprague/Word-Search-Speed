//
//  Item.swift
//  Word Search: Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation

#if canImport(SwiftData)
import SwiftData

@available(iOS 17, *)
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

#else

// iOS 16 fallback without SwiftData.
// Keep the same API surface so the rest of the code can reference Item.
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

#endif
