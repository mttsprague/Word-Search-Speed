//
//  GameCenterManager.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation
import GameKit
import UIKit
import Combine

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    private override init() {}

    // MARK: - Authentication

    func authenticateLocalPlayer() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { gcViewController, error in
            if let vc = gcViewController {
                UIApplication.shared.topViewController()?.present(vc, animated: true, completion: nil)
                return
            }

            if let error = error {
                NSLog("Game Center auth error: \(error.localizedDescription)")
                return
            }

            if player.isAuthenticated {
                NSLog("Game Center: authenticated as \(player.displayName)")
            } else {
                NSLog("Game Center: player not authenticated")
            }
        }
    }

    // MARK: - Submission

    // Submit to both daily and weekly boards so both stay in sync.
    // Skips submission for non-positive scores and unauthenticated players.
    func submit(score: Int) {
        guard score > 0 else {
            NSLog("Game Center: score <= 0; skipping submit.")
            return
        }

        guard GKLocalPlayer.local.isAuthenticated else {
            NSLog("Game Center: not authenticated; attempting auth then skipping submit for now.")
            authenticateLocalPlayer()
            return
        }

        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [GameCenterIDs.daily, GameCenterIDs.weekly]
        ) { error in
            if let error = error {
                NSLog("Game Center submit error: \(error.localizedDescription)")
            } else {
                NSLog("Game Center: submitted score \(score) to daily and weekly leaderboards")
            }
        }
    }

    // MARK: - Built-in UI (cannot restrict to 15)

    func showDailyLeaderboard() {
        showLeaderboard(leaderboardID: GameCenterIDs.daily, timeScope: .today)
    }

    func showWeeklyLeaderboard() {
        showLeaderboard(leaderboardID: GameCenterIDs.weekly, timeScope: .week)
    }

    private func showLeaderboard(leaderboardID: String, timeScope: GKLeaderboard.TimeScope) {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateLocalPlayer()
            return
        }

        let vc = GKGameCenterViewController(
            leaderboardID: leaderboardID,
            playerScope: .global,
            timeScope: timeScope
        )
        vc.gameCenterDelegate = self
        UIApplication.shared.topViewController()?.present(vc, animated: true)
    }

    // MARK: - Fetch top 15 entries (for custom UI)

    // Use these to display only top 15 in your own SwiftUI or UIKit view.
    // Note: These run on @MainActor because this class is @MainActor; that’s fine for light calls.
    func fetchTop15Daily() async throws -> [GKLeaderboard.Entry] {
        try await fetchTopEntries(leaderboardID: GameCenterIDs.daily, timeScope: .today, length: 15)
    }

    func fetchTop15Weekly() async throws -> [GKLeaderboard.Entry] {
        try await fetchTopEntries(leaderboardID: GameCenterIDs.weekly, timeScope: .week, length: 15)
    }

    private func fetchTopEntries(leaderboardID: String, timeScope: GKLeaderboard.TimeScope, length: Int) async throws -> [GKLeaderboard.Entry] {
        guard GKLocalPlayer.local.isAuthenticated else {
            // Try to authenticate and inform caller to retry later.
            authenticateLocalPlayer()
            throw NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not authenticated"])
        }

        // Load the specific leaderboard object
        let leaderboards = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[GKLeaderboard], Error>) in
            GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { lbs, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: lbs ?? [])
            }
        }

        guard let lb = leaderboards.first else {
            throw NSError(domain: "GameCenter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Leaderboard not found: \(leaderboardID)"])
        }

        // Get top N entries globally for the given time scope
        let range = NSRange(location: 1, length: max(1, length))
        let (_, entries, _, error) = await withCheckedContinuation { (cont: CheckedContinuation<(GKLeaderboard.Entry?, [GKLeaderboard.Entry]?, Int, Error?), Never>) in
            lb.loadEntries(for: .global, timeScope: timeScope, range: range) { local, entries, total, error in
                cont.resume(returning: (local, entries, total, error))
            }
        }

        if let error = error {
            throw error
        }

        return entries ?? []
    }

    // MARK: - Fetch local player rank/entry (for motivational UI)

    func fetchLocalDailyEntry() async throws -> GKLeaderboard.Entry? {
        try await fetchLocalEntry(leaderboardID: GameCenterIDs.daily, timeScope: .today)
    }

    func fetchLocalWeeklyEntry() async throws -> GKLeaderboard.Entry? {
        try await fetchLocalEntry(leaderboardID: GameCenterIDs.weekly, timeScope: .week)
    }

    // Convenience: fetch both top 15 and local player’s entry in one call (saves an extra load)
    func fetchTop15AndLocalDaily() async throws -> (top: [GKLeaderboard.Entry], local: GKLeaderboard.Entry?) {
        try await fetchTopAndLocal(leaderboardID: GameCenterIDs.daily, timeScope: .today, length: 15)
    }

    func fetchTop15AndLocalWeekly() async throws -> (top: [GKLeaderboard.Entry], local: GKLeaderboard.Entry?) {
        try await fetchTopAndLocal(leaderboardID: GameCenterIDs.weekly, timeScope: .week, length: 15)
    }

    // Internal helpers

    private func fetchLocalEntry(leaderboardID: String, timeScope: GKLeaderboard.TimeScope) async throws -> GKLeaderboard.Entry? {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateLocalPlayer()
            throw NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not authenticated"])
        }

        let leaderboards = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[GKLeaderboard], Error>) in
            GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { lbs, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: lbs ?? [])
            }
        }

        guard let lb = leaderboards.first else {
            throw NSError(domain: "GameCenter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Leaderboard not found: \(leaderboardID)"])
        }

        // A minimal range still returns the local player entry (even if rank is outside the range).
        let range = NSRange(location: 1, length: 1)
        let (local, _, _, error) = await withCheckedContinuation { (cont: CheckedContinuation<(GKLeaderboard.Entry?, [GKLeaderboard.Entry]?, Int, Error?), Never>) in
            lb.loadEntries(for: .global, timeScope: timeScope, range: range) { local, entries, total, error in
                cont.resume(returning: (local, entries, total, error))
            }
        }

        if let error = error {
            throw error
        }

        return local
    }

    private func fetchTopAndLocal(leaderboardID: String, timeScope: GKLeaderboard.TimeScope, length: Int) async throws -> (top: [GKLeaderboard.Entry], local: GKLeaderboard.Entry?) {
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticateLocalPlayer()
            throw NSError(domain: "GameCenter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not authenticated"])
        }

        let leaderboards = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[GKLeaderboard], Error>) in
            GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]) { lbs, error in
                if let error = error { cont.resume(throwing: error); return }
                cont.resume(returning: lbs ?? [])
            }
        }

        guard let lb = leaderboards.first else {
            throw NSError(domain: "GameCenter", code: -2, userInfo: [NSLocalizedDescriptionKey: "Leaderboard not found: \(leaderboardID)"])
        }

        let range = NSRange(location: 1, length: max(1, length))
        let (local, entries, _, error) = await withCheckedContinuation { (cont: CheckedContinuation<(GKLeaderboard.Entry?, [GKLeaderboard.Entry]?, Int, Error?), Never>) in
            lb.loadEntries(for: .global, timeScope: timeScope, range: range) { local, entries, total, error in
                cont.resume(returning: (local, entries, total, error))
            }
        }

        if let error = error {
            throw error
        }

        return (entries ?? [], local)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
