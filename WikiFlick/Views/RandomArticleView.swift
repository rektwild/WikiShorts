//
//  RandomArticleView.swift
//  WikiFlick
//
//  Random Article page - Shows truly random articles from all topics
//

import SwiftUI
import GoogleMobileAds

struct RandomArticleView: View {
    @ObservedObject private var randomManager = RandomArticleManager.shared
    @State private var currentIndex = 0
    @State private var feedItems: [FeedItem] = []
    @State private var selectedSearchArticle: WikipediaArticle?
    private let adMobManager = AdMobManager.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if randomManager.articles.isEmpty && randomManager.isLoading {
                FeedLoadingView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if randomManager.hasError {
                ErrorStateView(errorMessage: randomManager.errorMessage) {
                    refreshFeed()
                }
            } else if randomManager.articles.isEmpty && !randomManager.isLoading {
                EmptyStateView {
                    refreshFeed()
                }
            } else {
                GeometryReader { geometry in
                    if let searchArticle = selectedSearchArticle {
                        ArticleCardView(article: searchArticle, onNavigateToTop: nil)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else if #available(iOS 17.0, *) {
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
            if randomManager.articles.isEmpty {
                randomManager.loadArticles(isInitialLoad: true)
            }
        }
        .onChange(of: randomManager.articles) { newArticles in
            updateFeedItems()
        }
        .refreshable {
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRandomArticle"))) { _ in
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: .articleLanguageChanged)) { _ in
            refreshFeed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PremiumStatusChanged"))) { notification in
            print("🔄 Premium status changed - refreshing random articles")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshFeed()
            }
        }
    }
    
    private func refreshFeed() {
        randomManager.reset()
        feedItems.removeAll()
        currentIndex = 0
        adMobManager.resetArticleCount()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            randomManager.loadArticles(isInitialLoad: true)
        }
    }
    
    private func loadMoreContent() {
        LoggingService.shared.logInfo("Requesting more random articles", category: .general)
        randomManager.loadArticles(isInitialLoad: false)
    }
    
    private func updateFeedItems() {
        let newFeedItems = createFeedItems()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            feedItems = newFeedItems
        }
    }
    
    private func createFeedItems() -> [FeedItem] {
        var feedItems: [FeedItem] = []

        for (_, article) in randomManager.articles.enumerated() {
            feedItems.append(.article(article))
        }

        return feedItems
    }
}

#Preview {
    RandomArticleView()
}

