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
    private var interstitialDelegate: InterstitialDelegate?
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

        #if DEBUG
        let unitID = "ca-app-pub-3940256099942544/4411468910" // Google test interstitial
        #else
        let unitID = AdUnits.interstitial
        #endif

        let request = makeNonPersonalizedRequest()
        print("AdManager: Loading interstitial: \(unitID)")
        InterstitialAd.load(with: unitID, request: request) { [weak self] ad, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = error {
                    print("AdManager: Interstitial failed to load: \(error.localizedDescription)")
                    self.isInterstitialReady = false
                    return
                }
                if let ad = ad {
                    print("AdManager: Interstitial loaded.")
                    self.interstitial = ad
                    self.isInterstitialReady = true
                } else {
                    print("AdManager: Interstitial load returned nil ad.")
                    self.isInterstitialReady = false
                }
            }
        }
        #else
        isInterstitialReady = false
        interstitial = nil
        #endif
    }

    func loadRewarded(retryAfter seconds: TimeInterval? = nil) {
        #if canImport(GoogleMobileAds)
        isRewardedReady = false
        rewarded = nil

        let loadBlock = { [weak self] in
            guard let self else { return }
            #if DEBUG
            let unitID = "ca-app-pub-3940256099942544/5224354917" // Google test rewarded
            #else
            let unitID = AdUnits.rewarded
            #endif

            let request = makeNonPersonalizedRequest()
            print("AdManager: Loading rewarded: \(unitID)")
            RewardedAd.load(with: unitID, request: request) { [weak self] ad, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error = error {
                        print("AdManager: Rewarded failed to load: \(error.localizedDescription)")
                        self.isRewardedReady = false
                        #if DEBUG
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.loadRewarded()
                        }
                        #endif
                        return
                    }
                    if let ad = ad {
                        print("AdManager: Rewarded loaded.")
                        self.rewarded = ad
                        self.isRewardedReady = true
                    } else {
                        print("AdManager: Rewarded load returned nil ad.")
                        self.isRewardedReady = false
                        #if DEBUG
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.loadRewarded()
                        }
                        #endif
                    }
                }
            }
        }

        if let seconds = seconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                loadBlock()
            }
        } else {
            loadBlock()
        }
        #else
        isRewardedReady = false
        rewarded = nil
        #endif
    }

    func showInterstitialIfReady(onDismiss: (() -> Void)? = nil) {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitial, isInterstitialReady else {
            print("AdManager: Interstitial not ready.")
            onDismiss?()
            return
        }
        guard let vc = UIApplication.shared.topViewController() else {
            print("AdManager: No top view controller to present interstitial.")
            onDismiss?()
            return
        }

        isInterstitialReady = false
        interstitial = nil

        print("AdManager: Presenting interstitial.")
        
        // Set up a delegate to track when the ad is dismissed
        // Store it as a property to prevent it from being deallocated
        interstitialDelegate = InterstitialDelegate(onDismiss: onDismiss)
        ad.fullScreenContentDelegate = interstitialDelegate
        
        ad.present(from: vc)
        loadInterstitial()
        #else
        // No-op when GoogleMobileAds is unavailable
        onDismiss?()
        #endif
    }

    /// Presents rewarded and calls completion(true) if the user earned the reward.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewarded, isRewardedReady else {
            print("AdManager: Rewarded not ready.")
            completion(false)
            return
        }
        guard let vc = UIApplication.shared.topViewController() else {
            print("AdManager: No top view controller to present rewarded.")
            completion(false)
            return
        }

        isRewardedReady = false
        rewarded = nil

        print("AdManager: Presenting rewarded.")
        ad.present(from: vc) {
            print("AdManager: Reward earned.")
            completion(true)
        }

        // Preload the next one
        loadRewarded(retryAfter: 1)
        #else
        completion(false)
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func makeNonPersonalizedRequest() -> Request {
        let request = Request()
        // Non-personalized ads flag for AdMob
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
    #endif
}

#if canImport(GoogleMobileAds)
// Delegate to handle interstitial ad lifecycle events
private class InterstitialDelegate: NSObject, GADFullScreenContentDelegate {
    private let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)?) {
        self.onDismiss = onDismiss
        super.init()
    }
    
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("AdManager: Interstitial dismissed.")
        onDismiss?()
    }
    
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("AdManager: Interstitial failed to present: \(error.localizedDescription)")
        onDismiss?()
    }
}
#endif
