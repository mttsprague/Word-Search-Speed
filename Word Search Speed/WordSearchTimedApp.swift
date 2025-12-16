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
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        #endif
        return true
    }
}

