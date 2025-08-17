//
//  WikiShortsApp.swift
//  WikiShorts
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI
import AppTrackingTransparency

@main
struct WikiShortsApp: App {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    init() {
        // AdMob'u başlat
        let _ = AdMobManager.shared
        
        // Bildirim sistemini başlat
        let _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                ContentView()
                    .onAppear {
                        // Uygulama her açıldığında bildirimleri yenile
                        NotificationManager.shared.refreshNotifications()
                    }
            }
        }
    }
}
