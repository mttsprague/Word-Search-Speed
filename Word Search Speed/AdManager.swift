//
//  AdManager.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation
import UIKit
import Combine

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady = false

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    private var rewarded: RewardedAd?
    #else
    private var interstitial: Any?
    private var rewarded: Any?
    #endif

    private init() {}

    func preloadAll() {
        loadInterstitial()
        loadRewarded()
    }

    func loadInterstitial() {
        #if canImport(GoogleMobileAds)
        isInterstitialReady = false
        interstitial = nil

        let request = Request()
        InterstitialAd.load(with: AdUnits.interstitial, request: request) { [weak self] ad, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let ad = ad {
                    self.interstitial = ad
                    self.isInterstitialReady = true
                } else {
                    self.isInterstitialReady = false
                }
            }
        }
        #else
        isInterstitialReady = false
        interstitial = nil
        #endif
    }

    func loadRewarded() {
        #if canImport(GoogleMobileAds)
        isRewardedReady = false
        rewarded = nil

        let request = Request()
        RewardedAd.load(with: AdUnits.rewarded, request: request) { [weak self] ad, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let ad = ad {
                    self.rewarded = ad
                    self.isRewardedReady = true
                } else {
                    self.isRewardedReady = false
                }
            }
        }
        #else
        isRewardedReady = false
        rewarded = nil
        #endif
    }

    func showInterstitialIfReady() {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial, isInterstitialReady else { return }
        guard let vc = UIApplication.shared.topViewController() else { return }

        isInterstitialReady = false
        interstitial = nil

        ad.present(from: vc)
        loadInterstitial()
        #else
        // No-op when GoogleMobileAds is unavailable
        #endif
    }

    /// Presents rewarded and calls completion(true) if the user earned the reward.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewarded, isRewardedReady else {
            completion(false)
            return
        }
        guard let vc = UIApplication.shared.topViewController() else {
            completion(false)
            return
        }

        isRewardedReady = false
        rewarded = nil

        ad.present(from: vc) {
            completion(true)
        }

        loadRewarded()
        #else
        completion(false)
        #endif
    }
}
