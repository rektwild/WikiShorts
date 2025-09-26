import Foundation
import Combine
import UIKit

protocol WikipediaServiceProtocol: ObservableObject {
    var articles: [WikipediaArticle] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var hasError: Bool { get }
    var searchResults: [SearchResult] { get }
    var isSearching: Bool { get }
    
    func fetchRandomArticles(count: Int)
    func fetchTopicBasedArticles(count: Int)
    func loadMoreArticles()
    func searchWikipedia(query: String)
    func addSearchResultToFeed(_ searchResult: SearchResult)
    func clearSearchResults()
    func getCachedImage(for urlString: String) -> UIImage?
}

class WikipediaService: ObservableObject, WikipediaServiceProtocol {
    @Published var articles: [WikipediaArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasError = false
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    private var feedLoadingManager: FeedLoadingManager!
    
    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let articleLanguageManager = ArticleLanguageManager.shared
    private let imageLoadingService: ImageLoadingServiceProtocol
    private let searchHistoryManager = SearchHistoryManager.shared
    private let topicNormalizationService = TopicNormalizationService.shared
    private var currentLanguage: String = ""
    private var currentTopics: [String] = []
    
    init(
        articleRepository: ArticleRepositoryProtocol = ArticleRepository(),
        imageLoadingService: ImageLoadingServiceProtocol = ImageLoadingService.shared
    ) {
        self.articleRepository = articleRepository
        self.imageLoadingService = imageLoadingService
        
        // Initialize current settings from the same sources as onboarding/settings
        currentLanguage = articleLanguageManager.languageCode
        currentTopics = normalizedSelectedTopics

        setupNotificationObservers()

        Task { @MainActor in
            self.feedLoadingManager = FeedLoadingManager.shared
            syncWithFeedManager()
        }

        print("🚀 WikipediaService initialized with language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)) and topics: \(normalizedSelectedTopics)")
    }

    private func syncWithFeedManager() {
        Task { @MainActor in
            // Sync articles from FeedLoadingManager
            feedLoadingManager.$articles
                .receive(on: DispatchQueue.main)
                .sink { [weak self] articles in
                    self?.articles = articles
                }
                .store(in: &cancellables)

            // Sync loading state
            feedLoadingManager.$isLoading
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isLoading in
                    self?.isLoading = isLoading
                }
                .store(in: &cancellables)

            // Sync error state
            feedLoadingManager.$hasError
                .receive(on: DispatchQueue.main)
                .sink { [weak self] hasError in
                    self?.hasError = hasError
                }
                .store(in: &cancellables)

            feedLoadingManager.$errorMessage
                .receive(on: DispatchQueue.main)
                .sink { [weak self] errorMessage in
                    self?.errorMessage = errorMessage
                }
                .store(in: &cancellables)
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for article language changes from settings
        NotificationCenter.default.publisher(for: .articleLanguageChanged)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    print("📱 Article language changed from settings, refreshing...")
                    self?.checkForLanguageChangeAndRefresh()
                }
            }
            .store(in: &cancellables)
        
        // Listen for topic changes from settings  
        NotificationCenter.default.publisher(for: .topicsChanged)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    print("📝 Topics changed from settings, refreshing...")
                    self?.checkForTopicsChangeAndRefresh()
                }
            }
            .store(in: &cancellables)
    }
    
    private var selectedTopics: [String] {
        UserDefaults.standard.array(forKey: "selectedTopics") as? [String] ?? ["All Topics"]
    }

    private var normalizedSelectedTopics: [String] {
        topicNormalizationService.getNormalizedTopicsFromUserDefaults()
    }
    
    var languageCode: String {
        let code = articleLanguageManager.languageCode
        // Ensure language is supported for Wikipedia API
        if !articleLanguageManager.isLanguageSupported(articleLanguageManager.selectedLanguage) {
            print("⚠️ Language \(code) is not supported, falling back to English")
            return "en"
        }
        return code
    }
    
    func fetchRandomArticles(count: Int = 10) {
        // Delegate to FeedLoadingManager for centralized loading
        Task { @MainActor in
            feedLoadingManager.loadArticles(isInitialLoad: true)
        }
    }
    
    
    func loadMoreArticles() {
        // Delegate to FeedLoadingManager for centralized loading
        Task { @MainActor in
            feedLoadingManager.loadArticles(isInitialLoad: false)
        }
    }
    
    func fetchTopicBasedArticles(count: Int = 10) {
        // Delegate to FeedLoadingManager for centralized loading
        Task { @MainActor in
            feedLoadingManager.loadArticles(isInitialLoad: true)
        }
    }
    
    
    
    
    
    
    
    private func checkForLanguageChangeAndRefresh() {
        let newLanguage = articleLanguageManager.languageCode

        if newLanguage != currentLanguage {
            print("🔄 Language changed: \(currentLanguage) -> \(newLanguage)")
            currentLanguage = newLanguage
            Task { @MainActor in
                feedLoadingManager.handleLanguageChange()
            }
        }
    }
    
    private func checkForTopicsChangeAndRefresh() {
        let newTopics = normalizedSelectedTopics

        if newTopics != currentTopics {
            print("🔄 Topics changed: \(currentTopics) -> \(newTopics)")
            currentTopics = newTopics
            Task { @MainActor in
                feedLoadingManager.handleTopicsChange()
            }
        }
    }
    
    private func refreshArticles() {
        print("🔄 Refreshing articles for language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)), topics: \(normalizedSelectedTopics)")
        Task { @MainActor in
            feedLoadingManager.refresh()
        }
    }
    
    
    
    
    
    
    
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return imageLoadingService.getCachedImage(for: urlString)
    }
    
    func searchWikipedia(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel previous search task
        searchTask?.cancel()
        
        searchTask = Task {
            await performSearch(query: query)
        }
    }
    
    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        
        do {
            // Add debouncing delay - longer for better UX but not too long
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            let results = try await articleRepository.searchArticles(
                query: query,
                languageCode: languageCode
            ).async()
            
            if !Task.isCancelled {
                searchResults = results
                isSearching = false
                
                // Add to search history if we have results
                if !results.isEmpty {
                    searchHistoryManager.addSearchQuery(
                        query,
                        languageCode: languageCode,
                        resultCount: results.count
                    )
                    
                    // Preload images for search results in background
                    preloadSearchResultImages(results)
                }
            }
            
        } catch {
            if !Task.isCancelled {
                searchResults = []
                isSearching = false
            }
        }
    }
    
    func addSearchResultToFeed(_ searchResult: SearchResult) {
        Task {
            do {
                let fullArticle = try await articleRepository.fetchArticleDetails(
                    from: searchResult,
                    languageCode: languageCode
                ).async()
                await MainActor.run {
                    articles.insert(fullArticle, at: 0)
                }
            } catch {
                // Fallback to basic article if full details fail
                await MainActor.run {
                    let article = searchResult.wikipediaArticle
                    articles.insert(article, at: 0)
                }
            }
        }
    }
    
    
    func clearSearchResults() {
        searchResults = []
        searchTask?.cancel()
    }
    
    // MARK: - Private Helper Methods
    
    
    private func resetState() {
        Task { @MainActor in
            feedLoadingManager.reset()
        }
    }
    
    
    
    
    private func preloadSearchResultImages(_ results: [SearchResult]) {
        Task {
            for result in results.prefix(3) { // Preload only first 3 images to avoid excessive network usage
                if let imageURL = result.displayImageURL {
                    _ = await imageLoadingService.preloadImage(from: imageURL)
                }
            }
        }
    }
    
}

struct RandomArticleResponse: Codable {
    let pageId: Int
    let title: String
    let extract: String
    let thumbnail: ThumbnailResponse?
    let contentURLs: ContentURLs
    
    enum CodingKeys: String, CodingKey {
        case pageId = "pageid"
        case title, extract, thumbnail
        case contentURLs = "content_urls"
    }
}

struct ThumbnailResponse: Codable {
    let source: String
    let width: Int
    let height: Int
}

struct ContentURLs: Codable {
    let desktop: DesktopURL
}

struct DesktopURL: Codable {
    let page: String
}


