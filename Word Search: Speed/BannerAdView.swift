//
//  BannerAdView.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import GoogleMobileAds
import UIKit

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let view = GADBannerView(adSize: GADAdSizeBanner)
        view.adUnitID = adUnitID
        view.rootViewController = UIApplication.shared.topViewController()
        view.load(GADRequest())
        return view
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // Keep rootViewController updated for safety.
        uiView.rootViewController = UIApplication.shared.topViewController()
    }
}
