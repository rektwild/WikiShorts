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
        
        // ATT koordinasyonunu başlat - didBecomeActive olayını dinlemeye başlar
        ATTManager.shared.startATTCoordination()
        
        // AdMobManager'ı başlat - ATT bildirimi bekleyecek
        let _ = AdMobManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
                    .preferredColorScheme(.dark)
            } else {
                ContentView()
                    .preferredColorScheme(.dark)
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
