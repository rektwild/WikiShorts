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
            TodayView()
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
                                HStack(spacing: 8) {
                                    Button(action: {
                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshRandomArticle"), object: nil)
                                    }) {
                                        Image(systemName: "shuffle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
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
                                Button(action: {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRandomArticle"), object: nil)
                                }) {
                                    Image(systemName: "shuffle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                }
                .navigationViewStyle(.stack)
                .tabItem {
                    Label(languageManager.localizedString(key: "random_article"), systemImage: "shuffle")
                }
            }
            
            // Search Tab
            SearchView()
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
            HStack(spacing: 8) {
                // searchButton removed as we have a Search Tab now
                if !storeManager.isPurchased("wiki_m") {
                    giftButton
                }
                settingsButton
            }
        }
    }
    
    // Removed bottomToolbarItems (custom home circle)
    // Removed searchResultsOverlay and related subviews (SearchResultsSkeletonView, etc)

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

    // Removed backToFeedButton logic if it relied on custom overlay state, 
    // but keeping it simpler for now. If FeedView handles navigation internally via selectedSearchArticle, 
    // we might not need a manual back button in toolbar if we aren't overlaying.
    // However, the original code had backToFeedButton in leadingToolbarItems.
    
    private var removeAdsButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "nosign")
                    .font(.system(size: 12, weight: .medium))
                Text(languageManager.localizedString(key: "remove_ads"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
        }
    }

    private var giftButton: some View {
        Button(action: {
            if AdMobManager.shared.isRewardedAdLoaded {
                showingRewardAlert = true
            } else {
                showingNoAdAlert = true
            }
        }) {
            Image(systemName: "gift")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
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
