//
//  BannerAdView.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import UIKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct BannerAdView: View {
    let adUnitID: String

    // Observe consent so we don’t load before UMP completes.
    @ObservedObject private var consent = ConsentManager.shared

    var body: some View {
        #if canImport(GoogleMobileAds)
        Group {
            if consent.canRequestAds {
                BannerWrappedView(adUnitID: adUnitID)
                    .frame(width: 160, height: 25)
            } else {
                // Reserve space so layout doesn’t jump while waiting for consent.
                Color.clear
                    .frame(width: 160, height: 25)
            }
        }
        #else
        // Placeholder when the ads SDK is unavailable (e.g., Previews/CI)
        Color.clear
            .frame(width: 160, height: 25)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct BannerWrappedView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = adUnitID
        if let top = UIApplication.shared.topViewController() {
            view.rootViewController = top
        }
        // By the time we’re here, UMP has completed; safe to load.
        view.load(Request())
        return view
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if let top = UIApplication.shared.topViewController() {
            uiView.rootViewController = top
        }
    }
}
#endif

