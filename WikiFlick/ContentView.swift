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
    @StateObject private var wikipediaService = WikipediaService()
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared

    var body: some View {
        mainNavigationView
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
    
    @ViewBuilder
    private var mainNavigationView: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                mainContentView
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        leadingToolbarItems
                        trailingToolbarItems
                    }
                    .searchableResponsive(
                        text: $searchText,
                        isPresented: $isSearchFocused,
                        prompt: languageManager.localizedString(key: "search_wikipedia")
                    )
                    .onChange(of: searchText) { newValue in
                        isSearching = !newValue.isEmpty
                        wikipediaService.searchWikipedia(query: newValue)
                    }
                    .onSubmit(of: .search) {
                        if !searchText.isEmpty {
                            searchHistoryManager.addSearchQuery(
                                searchText,
                                languageCode: wikipediaService.languageCode,
                                resultCount: wikipediaService.searchResults.count
                            )
                        }
                    }
            }
        } else {
            NavigationView {
                mainContentView
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        leadingToolbarItems
                        trailingToolbarItems
                    }
                    .searchable(
                        text: $searchText,
                        prompt: languageManager.localizedString(key: "search_wikipedia")
                    )
                    .onChange(of: searchText) { newValue in
                        isSearching = !newValue.isEmpty
                        wikipediaService.searchWikipedia(query: newValue)
                    }
            }
            .navigationViewStyle(.stack)
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            FeedView(selectedSearchArticle: $selectedSearchArticle)
            if isSearching {
                searchResultsOverlay
            }
        }
    }
    
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 8) {
                profileButton
                if selectedSearchArticle != nil {
                    backToFeedButton
                } else if !storeManager.isPurchased("wiki_m") {
                    removeAdsButton
                }
            }
        }
    }
    
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                searchButton
                if !storeManager.isPurchased("wiki_m") {
                    giftButton
                }
                settingsButton
            }
        }
    }

    private var searchResultsOverlay: some View {
        VStack(spacing: 0) {
            if wikipediaService.isSearching {
                SearchResultsSkeletonView()
            } else if !wikipediaService.searchResults.isEmpty {
                SearchResultsListView(
                    searchResults: wikipediaService.searchResults,
                    onResultSelected: { result in
                        selectedSearchArticle = result.wikipediaArticle
                        searchText = ""
                        isSearching = false
                        wikipediaService.clearSearchResults()
                        // Dismiss keyboard
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            } else if !searchText.isEmpty {
                EmptySearchStateView(query: searchText)
            } else {
                // Show search history when search text is empty
                let recentSearches = searchHistoryManager.getRecentSearches(
                    for: wikipediaService.languageCode,
                    limit: 5
                )

                if !recentSearches.isEmpty {
                    SearchHistoryView(
                        searchHistory: recentSearches,
                        onHistoryItemTap: { query in
                            searchText = query
                            wikipediaService.searchWikipedia(query: query)
                        },
                        onClearHistory: {
                            searchHistoryManager.clearAllHistory()
                        }
                    )
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
        .background(Color.black.opacity(0.7))
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

    private var backToFeedButton: some View {
        Button(action: {
            selectedSearchArticle = nil
        }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 12, weight: .medium))
                Text(languageManager.localizedString(key: "back_to_feed"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
        }
    }

    private var searchButton: some View {
        Button(action: {
            isSearchFocused = true
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private var removeAdsButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack(spacing: 4) {
                Text(languageManager.localizedString(key: "remove_ads"))
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: "nosign")
                    .font(.system(size: 12, weight: .medium))
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
