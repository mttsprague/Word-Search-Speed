//
//  GameView.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import GameKit

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @StateObject private var ads = AdManager.shared

    @State private var showDifficultySheet = false

    // Leaderboard state
    @State private var showingDailyTop = false
    @State private var showingWeeklyTop = false
    @State private var dailyEntries: [GKLeaderboard.Entry] = []
    @State private var weeklyEntries: [GKLeaderboard.Entry] = []
    @State private var isLoadingDaily = false
    @State private var isLoadingWeekly = false
    @State private var leaderboardErrorDaily: String?
    @State private var leaderboardErrorWeekly: String?

    // Local rank
    @State private var localDailyRankText: String = "See where you stand"
    @State private var localWeeklyRankText: String = "Chase the trophy"

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
                .frame(width: 160, height: 25)
                .padding(.top, 6)
        }
        .padding(.vertical)
        .onAppear {
            vm.start()
            // Present difficulty selection if needed on first launch.
            showDifficultySheet = vm.needsDifficultySelection
            // Preload local rank teasers
            Task { await loadLocalRankTeasers() }
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
        .sheet(isPresented: $showingDailyTop) {
            LeaderboardSheet(
                title: "Daily Top 15",
                entries: dailyEntries,
                isLoading: isLoadingDaily,
                errorMessage: leaderboardErrorDaily
            )
        }
        .sheet(isPresented: $showingWeeklyTop) {
            LeaderboardSheet(
                title: "Weekly Top 15",
                entries: weeklyEntries,
                isLoading: isLoadingWeekly,
                errorMessage: leaderboardErrorWeekly
            )
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // Small leaderboard buttons ABOVE the stats row
            HStack(alignment: .center, spacing: 8) {
                LeaderboardCard(
                    titleTop: "Top 15",
                    titleBottom: "Today",
                    subtitle: localDailyRankText,
                    systemImage: "bolt.fill",
                    gradient: Gradient(colors: [Color(#colorLiteral(red: 1, green: 0.552, blue: 0.224, alpha: 1)), Color(#colorLiteral(red: 1, green: 0.224, blue: 0.361, alpha: 1))]),
                    glowColor: Color.orange.opacity(0.6)
                ) {
                    showingDailyTop = true
                    loadDailyTop15AndLocal()
                }

                LeaderboardCard(
                    titleTop: "Top 15",
                    titleBottom: "This Week",
                    subtitle: localWeeklyRankText,
                    systemImage: "trophy.fill",
                    gradient: Gradient(colors: [Color(#colorLiteral(red: 0.27, green: 0.62, blue: 1, alpha: 1)), Color(#colorLiteral(red: 0.36, green: 0.2, blue: 0.93, alpha: 1))]),
                    glowColor: Color.blue.opacity(0.6)
                ) {
                    showingWeeklyTop = true
                    loadWeeklyTop15AndLocal()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center) // let content control height
            .padding(.horizontal)

            // Stats row directly above the puzzle
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

                // Selected difficulty capsule
                Text(vm.difficulty.title)
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
        }
    }

    // Fetch just the local ranks to show in the teaser subtitles
    private func loadLocalRankTeasers() async {
        do {
            if let local = try await GameCenterManager.shared.fetchLocalDailyEntry() {
                localDailyRankText = "You’re #\(local.rank) today"
            } else {
                localDailyRankText = "Be first on the board!"
            }
        } catch {
            localDailyRankText = "Sign in to see your rank"
        }

        do {
            if let local = try await GameCenterManager.shared.fetchLocalWeeklyEntry() {
                localWeeklyRankText = "You’re #\(local.rank) this week"
            } else {
                localWeeklyRankText = "Make your mark this week!"
            }
        } catch {
            localWeeklyRankText = "Sign in to see your rank"
        }
    }

    private func loadDailyTop15AndLocal() {
        leaderboardErrorDaily = nil
        isLoadingDaily = true
        dailyEntries = []
        Task {
            do {
                let result = try await GameCenterManager.shared.fetchTop15AndLocalDaily()
                dailyEntries = result.top
                if let local = result.local {
                    localDailyRankText = "You’re #\(local.rank) today"
                }
            } catch {
                leaderboardErrorDaily = error.localizedDescription
            }
            isLoadingDaily = false
        }
    }

    private func loadWeeklyTop15AndLocal() {
        leaderboardErrorWeekly = nil
        isLoadingWeekly = true
        weeklyEntries = []
        Task {
            do {
                let result = try await GameCenterManager.shared.fetchTop15AndLocalWeekly()
                weeklyEntries = result.top
                if let local = result.local {
                    localWeeklyRankText = "You’re #\(local.rank) this week"
                }
            } catch {
                leaderboardErrorWeekly = error.localizedDescription
            }
            isLoadingWeekly = false
        }
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

    private func chip(for w: PlacedWord) -> some View {
        WordChipView(word: w.word, found: w.found)
    }

    // Layout: first line shows "Find:" + first word; second line shows the remaining two words, centered.
    private var wordChips: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("Find:")
                    .font(.headline)
                if let first = vm.puzzle.words.first {
                    chip(for: first)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(Array(vm.puzzle.words.dropFirst())) { w in
                    chip(for: w)
                }
                Spacer(minLength: 0)
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
                    HStack(spacing: 8) {
                        Text("Continue +10s")
                        Text(ads.isRewardedReady ? "" : "(Loading...)").opacity(0.7)
                    }
                }
                .buttonStyle(SlimBorderedButtonStyle())
                .disabled(!ads.isRewardedReady || vm.rewardedUsedThisRound)
            }

            Button("Next Puzzle") {
                vm.nextPuzzleTapped()
            }
            .buttonStyle(SlimProminentButtonStyle())

            HStack(spacing: 10) {
                Button("Daily Leaderboard") {
                    GameCenterManager.shared.showDailyLeaderboard()
                }
                .buttonStyle(SlimBorderedButtonStyle())

                Button("Weekly Leaderboard") {
                    GameCenterManager.shared.showWeeklyLeaderboard()
                }
                .buttonStyle(SlimBorderedButtonStyle())
            }

            Button("Change Difficulty") {
                // Only allow changing between rounds: present the sheet here.
                showDifficultySheet = true
                vm.needsDifficultySelection = true
            }
            .buttonStyle(SlimBorderedButtonStyle())

            Text("Interstitial: \(ads.isInterstitialReady ? "Ready" : "…")  •  Rewarded: \(ads.isRewardedReady ? "Ready" : "…")")
                .font(.caption2)
                .opacity(0.6)
        }
        .padding(16)
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

// Eye-catching gradient card for leaderboards (compact, half-width, fixed height)
private struct LeaderboardCard: View {
    let titleTop: String
    let titleBottom: String
    let subtitle: String
    let systemImage: String
    let gradient: Gradient
    let glowColor: Color
    let action: () -> Void

    @State private var isPressed = false
    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isPressed = false
            }
            action()
        }) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: glowColor, radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)

                        Text(titleTop.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Text(titleBottom)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            // Half-width via HStack expansion, fixed short height
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 44, alignment: .center)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: isPressed)
            .onAppear {
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    shimmerPhase = 160
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct LeaderboardSheet: View {
    let title: String
    let entries: [GKLeaderboard.Entry]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading…").opacity(0.7)
                    }
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if entries.isEmpty {
                    Text("No scores yet.")
                        .opacity(0.7)
                } else {
                    List(entries, id: \.player) { entry in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(rankColor(rank: entry.rank))
                                    .frame(width: 34, height: 34)
                                Text("\(entry.rank)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.player.displayName)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Text(entry.formattedScore)
                                    .font(.caption)
                                    .opacity(0.7)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func rankColor(rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return Color.blue.opacity(0.85)
        }
    }
}

// MARK: - Word Chip (extracted to avoid type-checker blowups)

private struct WordChipView: View {
    let word: String
    let found: Bool

    var body: some View {
        // Build text first with basic styling
        let text = Text(word)
            .strikethrough(found)
            .opacity(found ? 0.4 : 1.0)
            .multilineTextAlignment(.center)
            .lineLimit(nil) // allow wrapping to avoid truncation
            .allowsTightening(false)
            .fixedSize(horizontal: false, vertical: true)

        // Apply layout and decoration in separate steps
        return text
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .layoutPriority(1)
    }
}

// MARK: - Slim Button Styles

private struct SlimProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SlimBorderedButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.tint)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.tint, lineWidth: 1)
                    .opacity(0.6)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
