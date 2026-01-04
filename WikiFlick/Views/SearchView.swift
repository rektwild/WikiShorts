//
//  SearchView.swift
//  WikiShorts
//
//  Created by Sefa Cem Turan on 16.08.2025.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedSearchResult: SearchResult?
    @State private var showingPaywall = false
    @StateObject private var wikipediaService = WikipediaService()
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var languageManager = AppLanguageManager.shared
    
    @Binding var showingSettings: Bool
    @Binding var showingRewardAlert: Bool
    @Binding var showingNoAdAlert: Bool
    
    private let maxResults = 10
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if wikipediaService.searchResults.isEmpty && searchText.isEmpty {
                    // Empty state with search prompt
                    emptyStateView
                } else if wikipediaService.searchResults.isEmpty && wikipediaService.isSearching {
                    // Loading state
                    loadingView
                } else if wikipediaService.searchResults.isEmpty && !searchText.isEmpty {
                    // No results state
                    noResultsView
                } else {
                    // Search results list
                    searchResultsListView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: languageManager.localizedString(key: "search_wikipedia"))
            .onChange(of: searchText) { newValue in
                wikipediaService.searchWikipedia(query: newValue)
            }
            .sheet(item: $selectedSearchResult) { searchResult in
                if #available(iOS 16.0, *) {
                    ArticleCardView(
                        article: searchResult.wikipediaArticle,
                        onNavigateToTop: nil
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else {
                    ArticleCardView(
                        article: searchResult.wikipediaArticle,
                        onNavigateToTop: nil
                    )
                }
            }
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(isPresented: $showingPaywall)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            Text("Search Wikipedia")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Find articles, topics, and more")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            LoadingIndicatorView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            Text("No Results Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            Text("Try a different search term")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
    
    private var searchResultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(limitedSearchResults.enumerated()), id: \.element.id) { index, searchResult in
                    SearchResultCardView(searchResult: searchResult) {
                        selectedSearchResult = searchResult
                    }
                    
                    if index < min(maxResults - 1, limitedSearchResults.count - 1) {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var limitedSearchResults: [SearchResult] {
        Array(wikipediaService.searchResults.prefix(maxResults))
    }
}

#Preview {
    SearchView(
        showingSettings: .constant(false),
        showingRewardAlert: .constant(false),
        showingNoAdAlert: .constant(false)
    )
        .preferredColorScheme(.dark)
}
