import SwiftUI
import GoogleMobileAds

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

enum FeedItem {
    case article(WikipediaArticle)
    case nativeAd(NativeAd)
    case feedAd(NativeAd)
}

struct VerticalPageTabViewStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .scrollTargetBehavior(.paging)
        } else {
            content
        }
    }
}

struct FeedView: View {
    @StateObject private var wikipediaService = WikipediaService()
    @State private var currentIndex = 0
    @State private var feedItems: [FeedItem] = []
    @Binding var selectedSearchArticle: WikipediaArticle?
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
                GeometryReader { geometry in
                    // Show search result if available, otherwise show feed
                    if let searchArticle = selectedSearchArticle {
                        // Show selected search article in full screen
                        ArticleCardView(article: searchArticle, onNavigateToTop: nil)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if #available(iOS 17.0, *) {
                        // iOS 17+ - Use ScrollView with paging
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(feedItems.enumerated()), id: \.offset) { index, item in
                                    Group {
                                        switch item {
                                        case .article(let article):
                                            ArticleCardView(article: article, onNavigateToTop: {
                                                currentIndex = 0
                                            })
                                        case .nativeAd(let nativeAd):
                                            NativeAdCardView(nativeAd: nativeAd)
                                        case .feedAd(let nativeAd):
                                            FeedAdView(nativeAd: nativeAd)
                                        }
                                    }
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .onAppear {
                                        currentIndex = index

                                        if index >= feedItems.count - 3 {
                                            loadMoreContent()
                                        }

                                        // Only count articles, not ads, for interstitial logic
                                        if case .article(_) = feedItems[safe: index] {
                                            if adMobManager.shouldShowInterstitialAd() {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    adMobManager.showInterstitialAd()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .scrollTargetBehavior(.paging)
                        .ignoresSafeArea()
                    } else {
                        // iOS 16 and earlier - Use TabView
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
                                    case .feedAd(let nativeAd):
                                        FeedAdView(nativeAd: nativeAd)
                                    }
                                }
                                .tag(index)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(
                            width: geometry.size.height,
                            height: geometry.size.width
                        )
                        .rotationEffect(.degrees(90), anchor: .topLeading)
                        .offset(x: geometry.size.width, y: 0)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .ignoresSafeArea()
                        .onChange(of: currentIndex) { newIndex in
                            if newIndex >= feedItems.count - 3 {
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
        // Clear all state
        wikipediaService.articles.removeAll()
        feedItems.removeAll()
        currentIndex = 0
        adMobManager.resetArticleCount()

        // Small delay to ensure UI updates properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            wikipediaService.fetchTopicBasedArticles()
        }
    }
    
    private func loadMoreContent() {
        // The FeedLoadingManager now handles preventing concurrent loads
        LoggingService.shared.logInfo("Requesting more content", category: .general)
        wikipediaService.loadMoreArticles()
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
            
            // Add feed ad every 5 articles (instead of native ad)
            if adMobManager.shouldShowFeedAd(forArticleIndex: index) {
                if let nativeAd = adMobManager.currentNativeAd {
                    feedItems.append(.feedAd(nativeAd))
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
    FeedView(selectedSearchArticle: .constant(nil))
}