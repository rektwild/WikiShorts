//
//  ContentView.swift
//  WikiShorts
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var searchText = ""
    @State private var selectedSearchArticle: WikipediaArticle?
    @State private var showingRewardAlert = false
    @State private var showingNoAdAlert = false

    @State private var isSearching = false
    @State private var isSearchFocused = false
    @StateObject private var storeManager = StoreManager()
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared

    var body: some View {
        TabView {
            // Today Tab
            TodayView(
                showingSettings: $showingSettings,
                showingRewardAlert: $showingRewardAlert,
                showingNoAdAlert: $showingNoAdAlert
            )
            .tabItem {
                Label(languageManager.localizedString(key: "today"), systemImage: "doc.text.image")
            }
            
            // Feed Tab
            if #available(iOS 16.0, *) {
                NavigationStack {
                    feedContent
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .tabItem {
                    Label(languageManager.localizedString(key: "feed"), systemImage: "rectangle.stack")
                }
            } else {
                NavigationView {
                    feedContent
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(languageManager.localizedString(key: "feed"), systemImage: "rectangle.stack")
                }
            }
            
            // Random Article Tab
            if #available(iOS 16.0, *) {
                NavigationStack {
                    RandomArticleView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                WikiHeaderView(showingPaywall: $showingPaywall)
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                WikiTrailingHeaderView(
                                    showingSettings: $showingSettings,
                                    showingRewardAlert: $showingRewardAlert,
                                    showingNoAdAlert: $showingNoAdAlert
                                )
                            }
                        }
                }
                .tabItem {
                    Label(languageManager.localizedString(key: "random_article"), systemImage: "shuffle")
                }
            } else {
                NavigationView {
                    RandomArticleView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                WikiHeaderView(showingPaywall: $showingPaywall)
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                WikiTrailingHeaderView(
                                    showingSettings: $showingSettings,
                                    showingRewardAlert: $showingRewardAlert,
                                    showingNoAdAlert: $showingNoAdAlert
                                )
                            }
                        }
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(languageManager.localizedString(key: "random_article"), systemImage: "shuffle")
                }
            }
            
            // Search Tab
            SearchView(
                showingSettings: $showingSettings,
                showingRewardAlert: $showingRewardAlert,
                showingNoAdAlert: $showingNoAdAlert
            )
            .tabItem {
                Label(languageManager.localizedString(key: "search"), systemImage: "magnifyingglass")
            }
        }
        .accentColor(.white) // Ensure tab selection color fits dark theme
        .preferredColorScheme(.dark) // Enforce dark mode as per app style
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
        .alert(languageManager.localizedString(key: "rewarded_ad"), isPresented: $showingRewardAlert) {
            rewardAlertButtons
        } message: {
            Text(languageManager.localizedString(key: "ad_free_10_minutes"))
        }
        .alert(languageManager.localizedString(key: "no_ad_found"), isPresented: $showingNoAdAlert) {
            Button(languageManager.localizedString(key: "ok")) { }
        } message: {
            Text(languageManager.localizedString(key: "try_again_later"))
        }
        .environmentObject(languageManager)
        .environmentObject(storeManager)
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
    }
    
    @ViewBuilder
    private var feedContent: some View {
        FeedView(selectedSearchArticle: $selectedSearchArticle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                leadingToolbarItems
                trailingToolbarItems
            }
    }
    
    @ViewBuilder
    private var rewardAlertButtons: some View {
        Button(languageManager.localizedString(key: "watch_ad")) {
            if AdMobManager.shared.isRewardedAdLoaded {
                AdMobManager.shared.showRewardedAd()
            } else {
                showingNoAdAlert = true
            }
        }
        Button(languageManager.localizedString(key: "cancel"), role: .cancel) { }
    }
    
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 8) {
                profileButton
                if selectedSearchArticle != nil {
                    // Back button logic if needed, usually handled by NavStack automatically for pushed views
                    // But here selectedSearchArticle might be handling custom view switching within FeedView
                } else if !storeManager.isPurchased("wiki_m") {
                    removeAdsButton
                }
            }
        }
    }
    
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            WikiTrailingHeaderView(
                showingSettings: $showingSettings,
                showingRewardAlert: $showingRewardAlert,
                showingNoAdAlert: $showingNoAdAlert
            )
        }
    }
    
    private var profileButton: some View {
        Button(action: {
            if selectedSearchArticle != nil {
                selectedSearchArticle = nil
            } else {
                refreshFeed()
            }
        }) {
            Image("WikiShorts-pre")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        }
    }

    private var removeAdsButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "nosign")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                Text(languageManager.localizedString(key: "remove_ads"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
        }
    }

    private func refreshFeed() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
    }
}

#Preview {
    ContentView()
}
