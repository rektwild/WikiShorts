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
    
    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let articleLanguageManager = ArticleLanguageManager.shared
    private let imageLoadingService: ImageLoadingServiceProtocol
    private let errorHandler = ErrorHandlingService.shared
    private let retryManager = RetryManager()
    private let searchHistoryManager = SearchHistoryManager.shared
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
        currentTopics = selectedTopics
        
        setupNotificationObservers()
        
        print("🚀 WikipediaService initialized with language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)) and topics: \(selectedTopics)")
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
                        self.articles.append(contentsOf: articles)
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
            let articlesToAdd = Array(preloadedArticles.prefix(5))
            preloadedArticles.removeFirst(min(5, preloadedArticles.count))
            articles.append(contentsOf: articlesToAdd)
            
            // Preload more articles in background
            preloadArticlesInBackground()
        } else {
            fetchTopicBasedArticles(count: 5)
        }
    }
    
    func fetchTopicBasedArticles(count: Int = 10) {
        guard !isLoading else { return }
        
        setLoadingState(true)
        
        Task {
            do {
                let articles = try await retryManager.executeWithRetry(
                    id: "fetchTopicBasedArticles",
                    maxAttempts: 3
                ) {
                    try await self.articleRepository.fetchTopicBasedArticles(
                        topics: self.selectedTopics,
                        count: count,
                        languageCode: self.languageCode
                    ).async()
                }
                
                await MainActor.run {
                    self.setLoadingState(false)
                    if !articles.isEmpty {
                        self.articles.append(contentsOf: articles)
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
            refreshArticles()
        }
    }
    
    private func checkForTopicsChangeAndRefresh() {
        let newTopics = selectedTopics
        
        if newTopics != currentTopics {
            print("🔄 Topics changed: \(currentTopics) -> \(newTopics)")
            currentTopics = newTopics
            refreshArticles()
        }
    }
    
    private func refreshArticles() {
        print("🔄 Refreshing articles for language: \(articleLanguageManager.displayName) (\(articleLanguageManager.languageCode)), topics: \(selectedTopics)")
        
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
        guard !isPreloading && preloadedArticles.count < 10 else { return }
        
        isPreloading = true
        
        Task {
            let newArticles = await articleRepository.preloadArticles(
                count: 5,
                topics: selectedTopics,
                languageCode: languageCode
            )
            
            await MainActor.run {
                self.preloadedArticles.append(contentsOf: newArticles)
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


