//
//  AdManager.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady = false

    #if canImport(GoogleMobileAds)
    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?
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

        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdUnits.interstitial, request: request) { [weak self] ad, _ in
            guard let self else { return }
            if let ad = ad {
                self.interstitial = ad
                self.isInterstitialReady = true
            } else {
                self.isInterstitialReady = false
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

        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdUnits.rewarded, request: request) { [weak self] ad, _ in
            guard let self else { return }
            if let ad = ad {
                self.rewarded = ad
                self.isRewardedReady = true
            } else {
                self.isRewardedReady = false
            }
        }
        #else
        isRewardedReady = false
        rewarded = nil
        #endif
    }

    func showInterstitialIfReady() {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial as? GADInterstitialAd, isInterstitialReady else { return }
        guard let vc = UIApplication.shared.topViewController() else { return }

        isInterstitialReady = false
        interstitial = nil

        ad.present(fromRootViewController: vc)
        loadInterstitial()
        #else
        // No-op when GoogleMobileAds is unavailable
        #endif
    }

    /// Presents rewarded and calls completion(true) if the user earned the reward.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewarded as? GADRewardedAd, isRewardedReady else {
            completion(false)
            return
        }
        guard let vc = UIApplication.shared.topViewController() else {
            completion(false)
            return
        }

        isRewardedReady = false
        rewarded = nil

        ad.present(fromRootViewController: vc) {
            completion(true)
        }

        loadRewarded()
        #else
        completion(false)
        #endif
    }
}

