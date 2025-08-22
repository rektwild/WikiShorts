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
    @StateObject private var backgroundManager = AppBackgroundManager()
    
    init() {
        // Bildirim sistemini başlat
        let _ = NotificationManager.shared
        
        // Background refresh'i başlat
        let _ = BackgroundRefreshService.shared
        
        // ATT izni ve AdMob başlatma - uygulama başlatıldığında hemen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let _ = AdMobManager.shared
        }
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
                        // Background refresh'i planla
                        backgroundManager.scheduleBackgroundRefresh()
                    }
                    .withErrorHandling()
            }
        }
    }
}
