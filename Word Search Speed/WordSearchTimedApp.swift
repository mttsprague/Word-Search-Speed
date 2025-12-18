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

        #if canImport(GoogleMobileAds)
        #if DEBUG
        // Ensure test ads on simulator and this device
        // Use your logged test device ID along with the simulator literal.
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
            "SIMULATOR",
            "f950f1e4652072b41451e96ec6a559f3"
        ]
        #endif

        GADMobileAds.sharedInstance().start { _ in
            print("AdMob: started.")
            AdManager.shared.preloadAll()
        }
        #endif

        // Authenticate Game Center
        GameCenterManager.shared.authenticateLocalPlayer()

        return true
    }
}

