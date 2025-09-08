import SwiftUI
import GoogleMobileAds

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

enum FeedItem {
    case article(WikipediaArticle)
    case nativeAd(GADNativeAd)
}

struct FeedView: View {
    @StateObject private var wikipediaService = WikipediaService()
    @State private var currentIndex = 0
    @State private var feedItems: [FeedItem] = []
    @State private var isLoadingMore = false
    private let adMobManager = AdMobManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if wikipediaService.articles.isEmpty && wikipediaService.isLoading {
                FeedLoadingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if wikipediaService.hasError {
                ErrorStateView(errorMessage: wikipediaService.errorMessage) {
                    refreshFeed()
                }
            } else if wikipediaService.articles.isEmpty && !wikipediaService.isLoading {
                EmptyStateView {
                    refreshFeed()
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(feedItems.enumerated()), id: \.offset) { index, item in
                        Group {
                            switch item {
                            case .article(let article):
                                ArticleCardView(article: article, onNavigateToTop: {
                                    currentIndex = 0
                                })
                            case .nativeAd(let nativeAd):
                                NativeAdCardView(nativeAd: nativeAd)
                            }
                        }
                        .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .ignoresSafeArea()
                .onChange(of: currentIndex) { newIndex in
                    if newIndex >= feedItems.count - 2 && !isLoadingMore {
                        loadMoreContent()
                    }
                    
                    // Only count articles, not ads, for interstitial logic
                    if case .article(_) = feedItems[safe: newIndex] {
                        if adMobManager.shouldShowInterstitialAd() {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                adMobManager.showInterstitialAd()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if wikipediaService.articles.isEmpty {
                wikipediaService.fetchTopicBasedArticles()
            }
        }
        .onChange(of: wikipediaService.articles) { newArticles in
            updateFeedItems()
        }
        .refreshable {
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFeed"))) { _ in
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .articleLanguageChanged)) { _ in
            // Article language changed, refresh feed
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .topicsChanged)) { _ in
            // Topics changed, refresh feed
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PremiumStatusChanged"))) { notification in
            // Premium status changed, refresh feed to update ad visibility
            print("🔄 Premium status changed - refreshing feed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshFeed()
            }
        }
    }
    
    private func refreshFeed() {
        wikipediaService.articles.removeAll()
        feedItems.removeAll()
        currentIndex = 0
        isLoadingMore = false
        adMobManager.resetArticleCount()
        wikipediaService.fetchTopicBasedArticles()
    }
    
    private func loadMoreContent() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            wikipediaService.loadMoreArticles()
            self.isLoadingMore = false
        }
    }
    
    private func updateFeedItems() {
        let newFeedItems = createFeedItems()
        
        // Smooth update to prevent overlapping
        withAnimation(.easeInOut(duration: 0.2)) {
            feedItems = newFeedItems
        }
    }
    
    private func createFeedItems() -> [FeedItem] {
        var feedItems: [FeedItem] = []
        
        for (index, article) in wikipediaService.articles.enumerated() {
            feedItems.append(.article(article))
            
            // Add native ad every 5 articles
            if adMobManager.shouldShowNativeAd(forArticleIndex: index) {
                if let nativeAd = adMobManager.currentNativeAd {
                    feedItems.append(.nativeAd(nativeAd))
                }
            }
        }
        
        return feedItems
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            LoadingIndicatorView()
                .scaleEffect(2.0)
            
            Text("Loading articles...")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

struct EmptyStateView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No articles available")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Check your internet connection and try again")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(25)
        }
        .padding()
    }
}

struct ErrorStateView: View {
    let errorMessage: String?
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.8))
            
            Text("Something went wrong")
                .font(.title2)
                .foregroundColor(.white)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.red)
            .cornerRadius(25)
        }
        .padding()
    }
}

#Preview {
    FeedView()
}