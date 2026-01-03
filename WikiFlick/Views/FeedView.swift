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
                        // iOS 17+ - Use ScrollView with containerRelativeFrame for perfect paging
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
                                    .containerRelativeFrame([.horizontal, .vertical])
                                    .onAppear {
                                        currentIndex = index

                                        if index >= feedItems.count - 3 {
                                            loadMoreContent()
                                        }

                                        // Track page views and show ad every 10 pages
                                        if case .article(_) = feedItems[safe: index] {
                                            if adMobManager.incrementPageViewAndCheckAd() {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    adMobManager.showInterstitialAd()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .ignoresSafeArea()
                    } else {
                        // iOS 16 and earlier - Optimized TabView without rotation
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
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .indexViewStyle(.page(backgroundDisplayMode: .never))
                        .ignoresSafeArea()
                        .onChange(of: currentIndex) { newIndex in
                            if newIndex >= feedItems.count - 3 {
                                loadMoreContent()
                            }

                            // Track page views and show ad every 10 pages
                            if case .article(_) = feedItems[safe: newIndex] {
                                if adMobManager.incrementPageViewAndCheckAd() {
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

        for (_, article) in wikipediaService.articles.enumerated() {
            feedItems.append(.article(article))
            // No feed ads mixed in with articles anymore
            // Ads will be shown based on page views instead
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