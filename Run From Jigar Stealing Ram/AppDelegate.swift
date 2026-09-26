//
//  AppDelegate.swift
//  Run From Jigar Stealing Ram
//
//  Created by Administrator  on 25/9/2026.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Storyboard-based launch (no SceneDelegate) — this is the
        // pre-iOS 13 app lifecycle, so it works all the way back to
        // iOS 11 as long as there's no "Application Scene Manifest"
        // in Info.plist. See the note below.
        return true
    }

    // MARK: UISceneSession Lifecycle
    //
    // Deliberately NOT implementing application(_:configurationForConnecting:)
    // or application(_:didDiscardSceneSessions:) here. Those are part of
    // the iOS 13+ multi-scene API — adding them (or leaving a
    // SceneDelegate.swift in the project) pulls in scene-based launch,
    // which iOS 11/12 devices can't run.
}
