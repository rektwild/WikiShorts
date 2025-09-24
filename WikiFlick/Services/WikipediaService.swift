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
    private var preloadedArticles: [WikipediaArticle] = []
    private var isPreloading = false
    private var retryCount = 0
    private let maxRetries = 3
    private var fetchedArticleIds: Set<Int> = []  // Track fetched article IDs to prevent duplicates
    
    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let articleLanguageManager = ArticleLanguageManager.shared
    private let imageLoadingService: ImageLoadingServiceProtocol
    private let errorHandler = ErrorHandlingService.shared
    private let retryManager = RetryManager()
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
        
        print("🚀 WikipediaService initialized with language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)) and topics: \(normalizedSelectedTopics)")
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
        guard !isLoading else { return }
        
        setLoadingState(true)
        
        Task {
            do {
                let articles = try await retryManager.executeWithRetry(
                    id: "fetchRandomArticles",
                    maxAttempts: 3
                ) {
                    try await self.articleRepository.fetchRandomArticles(
                        count: count,
                        languageCode: self.languageCode
                    ).async()
                }
                
                await MainActor.run {
                    self.setLoadingState(false)
                    if !articles.isEmpty {
                        // Filter out duplicates before adding
                        let uniqueArticles = articles.filter { article in
                            !self.fetchedArticleIds.contains(article.pageId)
                        }

                        // Add unique articles and track their IDs
                        self.articles.append(contentsOf: uniqueArticles)
                        uniqueArticles.forEach { self.fetchedArticleIds.insert($0.pageId) }

                        self.clearErrorState()
                        self.preloadArticlesInBackground()
                    } else {
                        self.handleEmptyResult()
                    }
                }
            } catch {
                await MainActor.run {
                    self.setLoadingState(false)
                    if let repositoryError = error as? RepositoryError {
                        self.handleRepositoryError(repositoryError)
                    } else {
                        let appError = self.errorHandler.handle(error: error, context: "fetchRandomArticles")
                        self.hasError = true
                        self.errorMessage = appError.localizedDescription
                    }
                }
            }
        }
    }
    
    
    func loadMoreArticles() {
        // Use preloaded articles if available
        if !preloadedArticles.isEmpty {
            // Filter out duplicates from preloaded articles
            let uniquePreloaded = preloadedArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }

            let articlesToAdd = Array(uniquePreloaded.prefix(5))

            if !articlesToAdd.isEmpty {
                // Remove used articles from preloaded cache
                preloadedArticles.removeAll { article in
                    articlesToAdd.contains { $0.pageId == article.pageId }
                }

                // Add unique articles and track their IDs
                articles.append(contentsOf: articlesToAdd)
                articlesToAdd.forEach { fetchedArticleIds.insert($0.pageId) }
            }

            // Always try to preload more articles in background
            preloadArticlesInBackground()

            // If we couldn't add any unique articles from preloaded, fetch new ones
            if articlesToAdd.isEmpty {
                fetchTopicBasedArticles(count: 10)
            }
        } else {
            fetchTopicBasedArticles(count: 10)
        }
    }
    
    func fetchTopicBasedArticles(count: Int = 10) {
        guard !isLoading else { return }

        setLoadingState(true)

        Task {
            do {
                // Try category-based articles first
                let categories = topicNormalizationService.getCategoriesForTopics(normalizedSelectedTopics)

                let articles: [WikipediaArticle]
                if !categories.isEmpty && !normalizedSelectedTopics.contains("All Topics") {
                    // Use category-based fetching
                    articles = try await retryManager.executeWithRetry(
                        id: "fetchCategoryBasedArticles",
                        maxAttempts: 3
                    ) {
                        try await self.articleRepository.fetchCategoryBasedArticles(
                            categories: categories,
                            count: count,
                            languageCode: self.languageCode
                        ).async()
                    }
                } else {
                    // Fall back to topic-based search
                    articles = try await retryManager.executeWithRetry(
                        id: "fetchTopicBasedArticles",
                        maxAttempts: 3
                    ) {
                        try await self.articleRepository.fetchTopicBasedArticles(
                            topics: self.normalizedSelectedTopics,
                            count: count,
                            languageCode: self.languageCode
                        ).async()
                    }
                }

                await MainActor.run {
                    self.setLoadingState(false)
                    if !articles.isEmpty {
                        // Filter out duplicates before adding
                        let uniqueArticles = articles.filter { article in
                            !self.fetchedArticleIds.contains(article.pageId)
                        }

                        // Add unique articles and track their IDs
                        self.articles.append(contentsOf: uniqueArticles)
                        uniqueArticles.forEach { self.fetchedArticleIds.insert($0.pageId) }

                        self.clearErrorState()
                        self.preloadArticlesInBackground()
                    } else {
                        self.handleEmptyResult()
                    }
                }
            } catch {
                await MainActor.run {
                    self.setLoadingState(false)
                    if let repositoryError = error as? RepositoryError {
                        self.handleRepositoryError(repositoryError)
                    } else {
                        let appError = self.errorHandler.handle(error: error, context: "fetchTopicBasedArticles")
                        self.hasError = true
                        self.errorMessage = appError.localizedDescription
                    }
                }
            }
        }
    }
    
    
    
    
    
    
    
    private func checkForLanguageChangeAndRefresh() {
        let newLanguage = articleLanguageManager.languageCode

        if newLanguage != currentLanguage {
            print("🔄 Language changed: \(currentLanguage) -> \(newLanguage)")
            currentLanguage = newLanguage
            // Clear the tracked IDs when language changes to avoid conflicts
            fetchedArticleIds.removeAll()
            refreshArticles()
        }
    }
    
    private func checkForTopicsChangeAndRefresh() {
        let newTopics = normalizedSelectedTopics

        if newTopics != currentTopics {
            print("🔄 Topics changed: \(currentTopics) -> \(newTopics)")
            currentTopics = newTopics
            // Clear the tracked IDs when topics change to get fresh content
            fetchedArticleIds.removeAll()
            refreshArticles()
        }
    }
    
    private func refreshArticles() {
        print("🔄 Refreshing articles for language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)), topics: \(normalizedSelectedTopics)")
        
        // Reset state first
        resetState()
        
        // Cancel any existing requests
        cancellables.removeAll()
        
        // Small delay to ensure UI updates properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchTopicBasedArticles()
        }
    }
    
    private func preloadArticlesInBackground() {
        guard !isPreloading && preloadedArticles.count < 20 else { return }  // Increased buffer size

        isPreloading = true

        Task {
            // Use the same logic as fetchTopicBasedArticles for consistency
            let categories = topicNormalizationService.getCategoriesForTopics(normalizedSelectedTopics)

            let newArticles: [WikipediaArticle]
            if !categories.isEmpty && !normalizedSelectedTopics.contains("All Topics") {
                // Use category-based preloading
                newArticles = await articleRepository.preloadCategoryBasedArticles(
                    count: 15,  // Fetch more at once
                    categories: categories,
                    languageCode: languageCode
                )
            } else {
                // Use topic-based preloading
                newArticles = await articleRepository.preloadArticles(
                    count: 15,  // Fetch more at once
                    topics: normalizedSelectedTopics,
                    languageCode: languageCode
                )
            }

            await MainActor.run {
                // Only add articles that haven't been fetched yet
                let uniqueArticles = newArticles.filter { article in
                    !self.fetchedArticleIds.contains(article.pageId)
                }
                self.preloadedArticles.append(contentsOf: uniqueArticles)
                self.isPreloading = false
            }

            // Preload images for the fetched articles
            await articleRepository.preloadImages(for: newArticles)
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
    
    private func setLoadingState(_ loading: Bool) {
        isLoading = loading
        if loading {
            hasError = false
            errorMessage = nil
        }
    }
    
    private func clearErrorState() {
        hasError = false
        errorMessage = nil
    }
    
    private func resetState() {
        articles.removeAll()
        preloadedArticles.removeAll()
        fetchedArticleIds.removeAll()  // Clear tracked IDs when resetting
        isLoading = false
        isPreloading = false
        hasError = false
        errorMessage = nil
        retryCount = 0
    }
    
    private func handleRepositoryError(_ error: RepositoryError) {
        let appError = errorHandler.handle(error: error, context: "WikipediaService")
        hasError = true
        errorMessage = appError.localizedDescription
        
        print("🚨 Repository error: \(appError)")
        
        // Try fallback to English if not already using it and it's a language-related error
        if languageCode != "en", case .networkError(.notFound) = error {
            fallbackToEnglish()
        }
    }
    
    
    private func handleEmptyResult() {
        print("⚠️ No articles found for language '\(articleLanguageManager.displayName)' (\(languageCode))")
        
        setLoadingState(false)
        errorMessage = "No articles found for \(articleLanguageManager.displayName)"
        hasError = true
        
        // Try fallback to English if we're not already using English
        if languageCode != "en" && articleLanguageManager.isLanguageSupported(.english) {
            print("🔄 No articles found, attempting fallback to English...")
            fallbackToEnglish()
        } else {
            print("❌ Already using English or English not available")
            errorMessage = "No articles available. Please try again later."
        }
    }
    
    private func fallbackToEnglish() {
        // Temporarily override language to English
        let originalLanguage = articleLanguageManager.selectedLanguage
        
        // Set English as fallback
        articleLanguageManager.selectedLanguage = .english
        
        // Fetch articles in English
        setLoadingState(true)
        fetchRandomArticles(count: 5)
        
        // Restore original language setting after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.articleLanguageManager.selectedLanguage = originalLanguage
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


