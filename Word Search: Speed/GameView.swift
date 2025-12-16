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

            difficultyPicker

            // Banner at bottom (stable impressions)
            BannerAdView(adUnitID: AdUnits.banner)
                .frame(width: 320, height: 50)
                .padding(.top, 6)
        }
        .padding(.vertical)
        .onAppear { vm.start() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Time: \(vm.timeLeft)")
                    .font(.headline)
                Text("Streak: \(StatsStore.shared.streak)  •  Best: \(StatsStore.shared.bestSolveSeconds.map(String.init) ?? "-")s")
                    .font(.caption)
                    .opacity(0.8)
            }

            Spacer()

            Text(vm.difficulty.title)
                .font(.headline)
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

    private var difficultyPicker: some View {
        Picker("Difficulty", selection: $vm.difficulty) {
            ForEach(Difficulty.allCases, id: \.self) { d in
                Text(d.title).tag(d)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: vm.difficulty) { _ in
            vm.nextPuzzleTapped()
        }
    }

    private var resultOverlay: some View {
        VStack(spacing: 10) {
            Text(vm.phase == .won ? "You got them!" : "Time’s up!")
                .font(.title2).bold()

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
