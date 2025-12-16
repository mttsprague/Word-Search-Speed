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

    func makeUIView(context: Context) -> BannerView {
        let view = BannerView(adSize: AdSizeBanner)
        view.adUnitID = adUnitID
        if let top = UIApplication.shared.topViewController() {
            view.rootViewController = top
        }
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
