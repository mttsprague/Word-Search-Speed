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

    var body: some View {
        #if canImport(GoogleMobileAds)
        BannerWrappedView(adUnitID: adUnitID)
            .frame(width: 320, height: 50)
        #else
        // Placeholder when the ads SDK is unavailable (e.g., Previews/CI)
        Color.clear
            .frame(width: 320, height: 50)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct BannerWrappedView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner)
        view.adUnitID = adUnitID
        view.rootViewController = UIApplication.shared.topViewController()
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        uiView.rootViewController = UIApplication.shared.topViewController()
    }
}
#endif

