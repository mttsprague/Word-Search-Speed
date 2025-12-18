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
        AdaptiveBannerContainer(adUnitID: adUnitID)
        #else
        // Placeholder when the ads SDK is unavailable (e.g., Previews/CI)
        Color.clear
            .frame(height: 0)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdaptiveBannerContainer: View {
    let adUnitID: String
    @State private var height: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            AdaptiveBannerRepresentable(adUnitID: adUnitID, availableWidth: width, height: $height)
                .frame(width: width, height: height)
                .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

private struct AdaptiveBannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let availableWidth: CGFloat
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> ContainerView {
        let container = ContainerView()
        container.backgroundColor = .clear

        let banner = BannerView()
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator

        if let top = UIApplication.shared.topViewController() {
            banner.rootViewController = top
        }

        container.bannerView = banner
        container.addSubview(banner)

        banner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        updateBannerSizeAndLoad(banner: banner, width: availableWidth)

        return container
    }

    func updateUIView(_ container: ContainerView, context: Context) {
        guard let banner = container.bannerView else { return }
        if let top = UIApplication.shared.topViewController() {
            banner.rootViewController = top
        }
        updateBannerSizeAndLoad(banner: banner, width: availableWidth)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    private func updateBannerSizeAndLoad(banner: BannerView, width: CGFloat) {
        // Compute anchored adaptive size for the current orientation and width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.adSize = adSize

        let newHeight = adSize.size.height
        if abs(height - newHeight) > 0.5 {
            DispatchQueue.main.async {
                self.height = newHeight
            }
        }

        // Load/refresh the ad
        banner.load(Request())
    }

    final class ContainerView: UIView {
        var bannerView: BannerView?
        override var intrinsicContentSize: CGSize {
            if let bannerView {
                return CGSize(width: UIView.noIntrinsicMetric, height: bannerView.adSize.size.height)
            }
            return CGSize(width: UIView.noIntrinsicMetric, height: 0)
        }
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var height: CGFloat

        init(height: Binding<CGFloat>) {
            _height = height
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            let h = bannerView.adSize.size.height
            DispatchQueue.main.async {
                self.height = h
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("Banner failed to load: \(error.localizedDescription)")
            // Optional: collapse height on failure
            // DispatchQueue.main.async { self.height = 0 }
        }
    }
}
#endif
