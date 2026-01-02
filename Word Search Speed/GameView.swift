//
//  GameView.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import GameKit
import StoreKit

struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @StateObject private var ads = AdManager.shared

    @State private var showDifficultySheet = false
    @State private var showingScoringInfo = false

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
        ZStack {
            AnimatedBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                // Info button above the puzzle
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        vm.pauseTimer()
                        showingScoringInfo = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text("How scoring works")
                        }
                    }
                    .buttonStyle(SlimBorderedButtonStyle())
                    .padding(.horizontal)
                    Spacer(minLength: 0)
                }

                ZStack {
                    // Board container with glass effect
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 14)
                        .padding(.horizontal)

                    // Reserve explicit space for the difficulty badge, then place grid
                    VStack(spacing: 0) {
                        // Adjust this height to taste if you want the grid even lower
                        Spacer().frame(height: 72)

                        grid
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                    }
                    .padding(.horizontal)
                }
                .overlay(alignment: .topTrailing) {
                    // Difficulty badge on board
                    HStack(spacing: 6) {
                        Image(systemName: "dial.medium.fill")
                        Text(vm.difficulty.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(LinearGradient(colors: [.purple.opacity(0.9), .blue.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.trailing, 24)
                    .padding(.top, 8)
                    .opacity(vm.phase == .playing ? 1 : 0.8)
                }

                wordChips

                // Anchored adaptive banner at bottom (policy-safe)
                BannerAdView(adUnitID: AdUnits.banner)
                    .padding(.top, 6)
                    .opacity(0.9)
            }
            .padding(.vertical)
            .overlay {
                if vm.phase != .playing {
                    resultOverlay
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
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
        .sheet(isPresented: $showingScoringInfo, onDismiss: {
            vm.resumeTimer()
        }) {
            ScoringInfoSheet()
                .presentationDetents([.large])
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            // Small leaderboard buttons ABOVE the stats row
            HStack(alignment: .center, spacing: 10) {
                LeaderboardCard(
                    titleTop: "Top 15",
                    titleBottom: "Today",
                    subtitle: localDailyRankText,
                    systemImage: "bolt.fill",
                    gradient: Gradient(colors: [
                        Color(#colorLiteral(red: 1, green: 0.552, blue: 0.224, alpha: 1)),
                        Color(#colorLiteral(red: 1, green: 0.224, blue: 0.361, alpha: 1))
                    ]),
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
                    gradient: Gradient(colors: [
                        Color(#colorLiteral(red: 0.27, green: 0.62, blue: 1, alpha: 1)),
                        Color(#colorLiteral(red: 0.36, green: 0.2, blue: 0.93, alpha: 1))
                    ]),
                    glowColor: Color.blue.opacity(0.6)
                ) {
                    showingWeeklyTop = true
                    loadWeeklyTop15AndLocal()
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)

            // Stats row directly above the puzzle
            HStack(spacing: 10) {
                StatBadge(
                    title: "Time",
                    value: "\(vm.timeLeft)",
                    icon: "timer",
                    gradient: [.mint, .teal]
                )

                StatBadge(
                    title: "Score",
                    value: "\(vm.totalScore)",
                    icon: "star.fill",
                    gradient: [.yellow, .orange]
                )

                StatBadge(
                    title: "Streak",
                    value: "\(StatsStore.shared.streak)",
                    icon: "flame.fill",
                    gradient: [.pink, .red]
                )

                Spacer(minLength: 0)

                // Best time mini badge
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.checkmark")
                    Text(StatsStore.shared.bestSolveSeconds.map { "\($0)s" } ?? "-")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .opacity(0.9)
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
                // Subtle board backdrop grid
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )

                ForEach(0..<size, id: \.self) { r in
                    ForEach(0..<size, id: \.self) { c in
                        let p = GridPoint(r: r, c: c)
                        let x = CGFloat(c) * cell
                        let y = CGFloat(r) * cell

                        cellView(
                            char: vm.puzzle.grid.isEmpty ? " " : vm.puzzle.grid[r][c],
                            isFound: vm.isFoundCell(p),
                            isSelected: vm.isSelected(p),
                            difficulty: vm.difficulty
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

    private func cellView(char: Character, isFound: Bool, isSelected: Bool, difficulty: Difficulty) -> some View {
        let base = RoundedRectangle(cornerRadius: 8, style: .continuous)
        
        // Scale font size based on difficulty
        let fontSize: CGFloat = {
            switch difficulty {
            case .easy: return 24
            case .medium: return 20
            case .hard: return 18
            }
        }()

        return ZStack {
            base
                .fill(
                    isFound
                    ? LinearGradient(colors: [Color.green.opacity(0.45), Color.teal.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : isSelected
                    ? LinearGradient(colors: [Color.blue.opacity(0.45), Color.indigo.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    base.stroke(Color.white.opacity(isSelected || isFound ? 0.35 : 0.15), lineWidth: 1)
                )
                .shadow(color: (isSelected ? Color.blue : isFound ? Color.green : Color.black).opacity(isSelected || isFound ? 0.25 : 0.12),
                        radius: isSelected || isFound ? 6 : 3, x: 0, y: 2)

            Text(String(char))
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    isFound ? Color.white.opacity(0.95) :
                    isSelected ? Color.white.opacity(0.95) :
                    Color.white.opacity(0.9)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
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

    // Layout: line 1 = "Find"; line 2 = first word; line 3 = remaining two words. All centered.
    private var wordChips: some View {
        VStack(alignment: .center, spacing: 10) {
            // Line 1: "Find"
            HStack {
                Spacer(minLength: 0)
                Text("Find")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                Spacer(minLength: 0)
            }

            // Line 2: first word (if any)
            if let first = vm.puzzle.words.first {
                HStack {
                    Spacer(minLength: 0)
                    chip(for: first)
                    Spacer(minLength: 0)
                }
            }

            // Line 3: remaining two words (if any), centered
            let remaining = Array(vm.puzzle.words.dropFirst())
            if !remaining.isEmpty {
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    ForEach(remaining) { w in
                        chip(for: w)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
            .overlay(
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: vm.phase == .won ? "checkmark.seal.fill" : "hourglass")
                            .foregroundStyle(vm.phase == .won ? .green : .orange)
                        Text(vm.phase == .won ? "You got them!" : "Time’s up!")
                    }
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .padding(.bottom, 2)

                    // Score breakdown
                    if vm.lastRoundScore > 0 || vm.phase == .lost {
                        VStack(spacing: 4) {
                            let b = vm.lastRoundBreakdown
                            Text("Round Score: \(vm.lastRoundScore)")
                                .font(.headline)
                            if b != .empty && vm.phase == .won {
                                Text("Completion bonus: \(b.baseCompletionPoints)")
                                    .font(.caption)
                                    .opacity(0.85)
                                Text("Time bonus: \(b.timeLeftUsedForScoring) × \(b.difficultyMultiplier) = \(b.timeBonus)\(b.rewardedPenaltyApplied ? " (−15s ad penalty)" : "")")
                                    .font(.caption)
                                    .opacity(0.85)
                            } else if vm.phase == .lost {
                                Text("Your total \(vm.totalScore) will be submitted when you proceed.")
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
                                Image(systemName: "play.circle.fill")
                                Text("Continue +15s")
                                Text(ads.isRewardedReady ? "" : "(Loading...)").opacity(0.7)
                            }
                        }
                        .buttonStyle(SlimBorderedButtonStyle())
                        .disabled(!ads.isRewardedReady || vm.rewardedUsedThisRound)
                    }

                    Button {
                        vm.nextPuzzleTapped()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Next Puzzle")
                        }
                    }
                    .buttonStyle(SlimProminentButtonStyle())

                    HStack(spacing: 10) {
                        Button {
                            GameCenterManager.shared.showDailyLeaderboard()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                Text("Daily Leaderboard")
                            }
                        }
                        .buttonStyle(SlimBorderedButtonStyle())

                        Button {
                            GameCenterManager.shared.showWeeklyLeaderboard()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                Text("Weekly Leaderboard")
                            }
                        }
                        .buttonStyle(SlimBorderedButtonStyle())
                    }

                    Button {
                        // Only allow changing between rounds: present the sheet here.
                        showDifficultySheet = true
                        vm.needsDifficultySelection = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "dial.medium.fill")
                            Text("Change Difficulty")
                        }
                    }
                    .buttonStyle(SlimBorderedButtonStyle())
// Rate Us button
                    Button {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: windowScene)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                            Text("Rate Us")
                        }
                    }
                    .buttonStyle(SlimBorderedButtonStyle())

                    
                    Text("Interstitial: \(ads.isInterstitialReady ? "Ready" : "…")  •  Rewarded: \(ads.isRewardedReady ? "Ready" : "…")")
                        .font(.caption2)
                        .opacity(0.6)
                }
                .padding(16)
            )
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

private struct DifficultySelectionSheet: View {
    let select: (Difficulty) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Select Difficulty")
                .font(.headline)

            DifficultyRow(title: Difficulty.easy.title, subtitle: "10×10 • 3 words • 45s", action: { select(.easy) })
            DifficultyRow(title: Difficulty.medium.title, subtitle: "12×12 • 3 words • 45s", action: { select(.medium) })
            DifficultyRow(title: Difficulty.hard.title, subtitle: "14×14 • 3 words • 45s", action: { select(.hard) })
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

// MARK: - Scoring Info

private struct ScoringInfoSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scoring")
                        .font(.title2.weight(.bold))

                    Group {
                        Text("• Complete a puzzle to earn a base bonus: Easy 100, Medium 200, Hard 300.")
                        Text("• Time bonus = time left × difficulty multiplier (Easy ×1, Medium ×2, Hard ×3).")
                        Text("• Find a word during play: +5s added to the clock.")
                        Text("• Continue after watching a rewarded ad: +15s play window, but a −15s time penalty is applied when computing the time bonus for that round.")
                        Text("• Scores keep accumulating across completed puzzles. They reset only after a failed puzzle (if you don’t continue) or if you change difficulty.")
                        Text("• Your accumulated score is submitted to the leaderboard after a failed puzzle.")
                    }
                    .font(.body)
                    .opacity(0.92)

                    Divider().opacity(0.3)

                    Text("Example")
                        .font(.headline)
                    Text("If you finish with 12 seconds left on Hard: time bonus = 12 × 3 = 36. If you used the rewarded continue, we subtract 15s before scoring the time bonus. So with 12s showing, time used for scoring becomes max(0, 12 − 15) = 0. Your round score would be 300 + 0 = 300.")
                        .font(.callout)
                        .opacity(0.85)
                }
                .padding()
            }
            .navigationTitle("How Scoring Works")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Word Chip (extracted to avoid type-checker blowups)

private struct WordChipView: View {
    let word: String
    let found: Bool

    var body: some View {
        let gradient = found
        ? LinearGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.25)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)
        : LinearGradient(colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.9)],
                         startPoint: .topLeading, endPoint: .bottomTrailing)

        let text = HStack(spacing: 8) {
            if found {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text(word)
                .strikethrough(found)
                .opacity(found ? 0.6 : 1.0)
        }
        .multilineTextAlignment(.center)
        .lineLimit(nil)
        .allowsTightening(false)
        .fixedSize(horizontal: false, vertical: true)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)

        return text
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: (found ? Color.black : Color.blue).opacity(0.15), radius: 6, x: 0, y: 3)
            .layoutPriority(1)
    }
}

// MARK: - Slim Button Styles

private struct SlimProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.blue.opacity(0.25), radius: 10, x: 0, y: 6)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct SlimBorderedButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Decorative Views

private struct AnimatedBackdrop: View {
    @State private var t: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { context in
            let phase = CGFloat((context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6)) / 6.0)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.09, blue: 0.15),
                        Color(red: 0.05, green: 0.06, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.25),
                        Color.blue.opacity(0.25),
                        Color.cyan.opacity(0.25),
                        Color.pink.opacity(0.25),
                        Color.purple.opacity(0.25)
                    ]),
                    center: .center,
                    angle: .degrees(Double(phase) * 360)
                )
                .blur(radius: 160)

                // Vignette
                RadialGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                               center: .center, startRadius: 0, endRadius: 800)
            }
            .animation(.linear(duration: 6), value: phase)
        }
    }
}

private struct StatBadge: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
