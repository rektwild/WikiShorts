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
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var selectedSearchArticle: WikipediaArticle?
    @State private var showingRewardAlert = false
    @State private var showingNoAdAlert = false
    @StateObject private var storeManager = StoreManager()
    @StateObject private var wikipediaService = WikipediaService()
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared

    var body: some View {
        ZStack {
            // Main feed content
            FeedView(selectedSearchArticle: $selectedSearchArticle)

            // Fixed header overlay
            VStack {
                topHeaderView
                Spacer()
            }

            // Search overlays
            if isSearchActive {
                searchOverlays
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
        .alert(languageManager.localizedString(key: "rewarded_ad"), isPresented: $showingRewardAlert) {
            Button(languageManager.localizedString(key: "watch_ad")) {
                if AdMobManager.shared.isRewardedAdLoaded {
                    AdMobManager.shared.showRewardedAd()
                } else {
                    showingNoAdAlert = true
                }
            }
            Button(languageManager.localizedString(key: "cancel"), role: .cancel) { }
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

    private var topHeaderView: some View {
        HStack(spacing: 8) {
            profileButton

            if isSearchActive {
                searchBarView
            } else {
                if selectedSearchArticle != nil {
                    backToFeedButton
                } else if !storeManager.isPurchased("wiki_m") {
                    removeAdsButton
                }
                Spacer()
                if !storeManager.isPurchased("wiki_m") {
                    searchButton
                    giftButton
                } else {
                    searchButton
                }
            }
            settingsButton
        }
        .padding(.horizontal, 10)
        .padding(.top, 60)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.6),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .ignoresSafeArea(edges: .top)
        )
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
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var backToFeedButton: some View {
        Button(action: {
            selectedSearchArticle = nil
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Text(languageManager.localizedString(key: "back_to_feed"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var searchButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSearchActive = true
            }
        }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var removeAdsButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack(spacing: 6) {
                Text(languageManager.localizedString(key: "remove_ads"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: "nosign")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
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
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    private var searchBarView: some View {
        SearchBarView(
            searchText: $searchText,
            isActive: $isSearchActive,
            onCancel: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSearchActive = false
                    searchText = ""
                    wikipediaService.clearSearchResults()
                }
            },
            onClear: {
                searchText = ""
                wikipediaService.clearSearchResults()
            }
        )
        .onChange(of: searchText) { newValue in
            wikipediaService.searchWikipedia(query: newValue)
        }
    }

    private var searchOverlays: some View {
        VStack(spacing: 0) {
            // Top spacing to position results below search bar
            Rectangle()
                .fill(Color.clear)
                .frame(height: 140)

            if wikipediaService.isSearching {
                SearchResultsSkeletonView()
            } else if !wikipediaService.searchResults.isEmpty {
                SearchResultsListView(
                    searchResults: wikipediaService.searchResults,
                    onResultSelected: { result in
                        selectedSearchArticle = result.wikipediaArticle
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchActive = false
                            searchText = ""
                            wikipediaService.clearSearchResults()
                        }
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
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    private func refreshFeed() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
    }
}

#Preview {
    ContentView()
}
