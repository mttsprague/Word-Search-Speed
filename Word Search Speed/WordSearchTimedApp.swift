//
//  WordSearchTimedApp.swift
//  Word Search Speed
//
//  Created by Matthew Sprague on 12/16/25.
//

import SwiftUI
import GoogleMobileAds

@main
struct WordSearchTimedApp: App {
    // Needed to initialize ads early in SwiftUI apps.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Debug: confirm the AdMob App ID is present at runtime
        let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String
        print("GADApplicationIdentifier =", appID ?? "MISSING")

        #if DEBUG
        assert(appID != nil && appID?.isEmpty == false, "GADApplicationIdentifier is missing from Info.plist")
        #else
        if appID == nil || appID?.isEmpty == true {
            NSLog("Warning: GADApplicationIdentifier is missing from Info.plist. Ads will not be initialized.")
        }
        #endif

        // 1) Gather consent (UMP), then 2) optionally request ATT, then 3) start AdMob and preload ads.
        ConsentManager.shared.gatherConsent {
            ConsentManager.shared.requestATTIfNeeded {
                #if canImport(GoogleMobileAds)
                MobileAds.shared.start { _ in
                    // Preload interstitial/rewarded once SDK is ready and consent flow finished.
                    AdManager.shared.preloadAll()
                }
                #endif
            }
        }

        // Authenticate Game Center
        GameCenterManager.shared.authenticateLocalPlayer()

        return true
    }
}

