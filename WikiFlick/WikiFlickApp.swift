//
//  WikiFlickApp.swift
//  WikiFlick
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

@main
struct WikiFlickApp: App {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                ContentView()
            }
        }
    }
}
