//
//  AdManager.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    @Published private(set) var isInterstitialReady = false
    @Published private(set) var isRewardedReady = false

    private var interstitial: GADInterstitialAd?
    private var rewarded: GADRewardedAd?

    private init() {}

    func preloadAll() {
        loadInterstitial()
        loadRewarded()
    }

    func loadInterstitial() {
        isInterstitialReady = false
        interstitial = nil

        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: AdUnits.interstitial, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let ad = ad {
                self.interstitial = ad
                self.isInterstitialReady = true
            } else {
                self.isInterstitialReady = false
                // You can log error?.localizedDescription if you want.
            }
        }
    }

    func loadRewarded() {
        isRewardedReady = false
        rewarded = nil

        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: AdUnits.rewarded, request: request) { [weak self] ad, error in
            guard let self else { return }
            if let ad = ad {
                self.rewarded = ad
                self.isRewardedReady = true
            } else {
                self.isRewardedReady = false
            }
        }
    }

    func showInterstitialIfReady() {
        guard let ad = interstitial, isInterstitialReady else { return }
        guard let vc = UIApplication.shared.topViewController() else { return }

        isInterstitialReady = false
        interstitial = nil

        ad.present(fromRootViewController: vc)
        loadInterstitial()
    }

    /// Presents rewarded and calls completion(true) if the user earned the reward.
    func showRewarded(completion: @escaping (Bool) -> Void) {
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

        ad.present(fromRootViewController: vc) {
            completion(true)
        }

        loadRewarded()
    }
}

