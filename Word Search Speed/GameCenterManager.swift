//
//  GameCenterManager.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation
import GameKit
import UIKit

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    private override init() {}

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

    // Submit to both daily and weekly boards so both stay in sync.
    func submit(score: Int) {
        guard GKLocalPlayer.local.isAuthenticated else {
            NSLog("Game Center: not authenticated; skipping submit.")
            return
        }

        let dailyScore  = GKScore(leaderboardIdentifier: GameCenterIDs.daily)
        let weeklyScore = GKScore(leaderboardIdentifier: GameCenterIDs.weekly)

        dailyScore.value  = Int64(score)
        weeklyScore.value = Int64(score)

        GKScore.report([dailyScore, weeklyScore]) { error in
            if let error = error {
                NSLog("Game Center submit error: \(error.localizedDescription)")
            } else {
                NSLog("Game Center: submitted score \(score) to daily and weekly leaderboards")
            }
        }
    }

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

        let vc = GKGameCenterViewController(leaderboardID: leaderboardID,
                                            playerScope: .global,
                                            timeScope: timeScope)
        vc.gameCenterDelegate = self
        UIApplication.shared.topViewController()?.present(vc, animated: true)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}

