//
//  GameView.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @StateObject private var ads = AdManager.shared

    @State private var showDifficultySheet = false

    var body: some View {
        VStack(spacing: 12) {
            header

            ZStack {
                grid
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal)

                if vm.phase != .playing {
                    resultOverlay
                }
            }

            wordChips

            // Banner at bottom (stable impressions)
            BannerAdView(adUnitID: AdUnits.banner)
                .frame(width: 320, height: 50)
                .padding(.top, 6)
        }
        .padding(.vertical)
        .onAppear {
            vm.start()
            // Present difficulty selection if needed on first launch.
            showDifficultySheet = vm.needsDifficultySelection
        }
        .onChange(of: vm.needsDifficultySelection) { needed in
            showDifficultySheet = needed
        }
        .sheet(isPresented: $showDifficultySheet) {
            DifficultySelectionSheet { chosen in
                vm.applyDifficulty(chosen)
            }
            .presentationDetents([.fraction(0.35)])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Time: \(vm.timeLeft)")
                    .font(.headline)
                Text("Score: \(vm.totalScore)")
                    .font(.headline)
                Text("Streak: \(StatsStore.shared.streak)  •  Best: \(StatsStore.shared.bestSolveSeconds.map(String.init) ?? "-")s")
                    .font(.caption)
                    .opacity(0.8)
            }

            Spacer()

            // Show the currently selected difficulty as a category label.
            Text(vm.difficulty.title)
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal)
    }

    private var grid: some View {
        GeometryReader { geo in
            let size = vm.puzzle.size
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(max(size, 1))

            ZStack(alignment: .topLeading) {
                ForEach(0..<size, id: \.self) { r in
                    ForEach(0..<size, id: \.self) { c in
                        let p = GridPoint(r: r, c: c)
                        let x = CGFloat(c) * cell
                        let y = CGFloat(r) * cell

                        cellView(
                            char: vm.puzzle.grid.isEmpty ? " " : vm.puzzle.grid[r][c],
                            isFound: vm.isFoundCell(p),
                            isSelected: vm.isSelected(p)
                        )
                        .frame(width: cell, height: cell)
                        .position(x: x + cell/2, y: y + cell/2)
                    }
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        vm.dragChanged(at: pointFrom(location: value.location, cell: cell, gridSize: size))
                    }
                    .onEnded { _ in
                        vm.dragEnded()
                    }
            )
        }
    }

    private func cellView(char: Character, isFound: Bool, isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isFound ? Color.green.opacity(0.35)
                      : isSelected ? Color.blue.opacity(0.25)
                      : Color.gray.opacity(0.12))

            Text(String(char))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func pointFrom(location: CGPoint, cell: CGFloat, gridSize: Int) -> GridPoint? {
        let c = Int(location.x / cell)
        let r = Int(location.y / cell)
        guard r >= 0, r < gridSize, c >= 0, c < gridSize else { return nil }
        return GridPoint(r: r, c: c)
    }

    private var wordChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Find:")
                .font(.headline)

            HStack {
                ForEach(vm.puzzle.words) { w in
                    Text(w.word)
                        .strikethrough(w.found)
                        .opacity(w.found ? 0.4 : 1.0)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
    }

    private var resultOverlay: some View {
        VStack(spacing: 10) {
            Text(vm.phase == .won ? "You got them!" : "Time’s up!")
                .font(.title2).bold()

            // Score breakdown
            if vm.lastRoundScore > 0 || vm.phase == .lost {
                VStack(spacing: 4) {
                    let b = vm.lastRoundBreakdown
                    Text("Round Score: \(vm.lastRoundScore)")
                        .font(.headline)
                    if b != .empty {
                        Text("Words: \(b.wordsFound) × 100 = \(b.wordPoints)")
                            .font(.caption)
                            .opacity(0.8)
                        Text("Time bonus: \(b.timeLeftUsedForScoring) × \(b.difficultyMultiplier) = \(b.timeBonus)\(b.rewardedPenaltyApplied ? " (−10s ad penalty)" : "")")
                            .font(.caption)
                            .opacity(0.8)
                    } else {
                        Text("Score will finalize when you proceed.")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
                .padding(.top, 4)
            }

            if vm.phase == .lost {
                Button {
                    vm.continueWithRewarded()
                } label: {
                    HStack {
                        Text("Continue +10s")
                        Text(ads.isRewardedReady ? "" : "(Loading...)").opacity(0.7)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!ads.isRewardedReady || vm.rewardedUsedThisRound)
            }

            Button("Next Puzzle") {
                vm.nextPuzzleTapped()
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Button("Daily Leaderboard") {
                    GameCenterManager.shared.showDailyLeaderboard()
                }
                .buttonStyle(.bordered)

                Button("Weekly Leaderboard") {
                    GameCenterManager.shared.showWeeklyLeaderboard()
                }
                .buttonStyle(.bordered)
            }

            Button("Change Difficulty") {
                // Only allow changing between rounds: present the sheet here.
                showDifficultySheet = true
                vm.needsDifficultySelection = true
            }
            .buttonStyle(.bordered)

            Text("Interstitial: \(ads.isInterstitialReady ? "Ready" : "…")  •  Rewarded: \(ads.isRewardedReady ? "Ready" : "…")")
                .font(.caption2)
                .opacity(0.6)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct DifficultySelectionSheet: View {
    let select: (Difficulty) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Select Difficulty")
                .font(.headline)

            DifficultyRow(title: Difficulty.easy.title, subtitle: "10×10 • 3 words • 30s", action: { select(.easy) })
            DifficultyRow(title: Difficulty.medium.title, subtitle: "12×12 • 3 words • 30s", action: { select(.medium) })
            DifficultyRow(title: Difficulty.hard.title, subtitle: "14×14 • 3 words • 30s", action: { select(.hard) })
        }
        .padding()
    }

    private struct DifficultyRow: View {
        let title: String
        let subtitle: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).opacity(0.7)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

