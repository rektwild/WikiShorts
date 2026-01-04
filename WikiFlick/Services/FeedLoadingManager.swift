import Foundation
import Combine

/// Centralized feed loading manager to prevent conflicts and handle all article fetching
@MainActor
class FeedLoadingManager: ObservableObject {
    static let shared = FeedLoadingManager()

    // MARK: - Published Properties
    @Published var articles: [WikipediaArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasError = false

    // MARK: - Private Properties
    private var preloadedArticles: [WikipediaArticle] = []
    private var fetchedArticleIds: Set<Int> = []
    private var isPreloading = false
    private var activeFetchTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?

    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let articleLanguageManager = ArticleLanguageManager.shared
    private let topicNormalizationService = TopicNormalizationService.shared
    private let retryManager = RetryManager()

    // Configuration
    private let articlesPerBatch = 10
    private let preloadBatchSize = 15
    private let preloadThreshold = 20

    private init(articleRepository: ArticleRepositoryProtocol = ArticleRepository()) {
        self.articleRepository = articleRepository
    }

    // MARK: - Public Methods

    /// Main method to load articles - handles both initial and additional loads
    func loadArticles(isInitialLoad: Bool = false) {
        // Cancel any existing fetch to prevent conflicts
        activeFetchTask?.cancel()

        activeFetchTask = Task {
            await performLoad(isInitialLoad: isInitialLoad)
        }
    }

    /// Clear all articles and reset state
    func reset() {
        // Cancel tasks gracefully
        activeFetchTask?.cancel()
        preloadTask?.cancel()

        // Wait a tiny bit for cancellation to complete
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

            articles.removeAll()
            preloadedArticles.removeAll()
            fetchedArticleIds.removeAll()
            isLoading = false
            isPreloading = false
            hasError = false
            errorMessage = nil
        }
    }

    /// Refresh feed with new content
    func refresh() {
        // Cancel existing tasks
        activeFetchTask?.cancel()
        preloadTask?.cancel()

        // Create new task for refresh
        Task {
            // Small delay to ensure cancellation completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

            // Clear state
            articles.removeAll()
            preloadedArticles.removeAll()
            fetchedArticleIds.removeAll()
            isLoading = false
            isPreloading = false
            hasError = false
            errorMessage = nil

            // Load new articles
            loadArticles(isInitialLoad: true)
        }
    }

    // MARK: - Private Methods

    private func performLoad(isInitialLoad: Bool) async {
        // Prevent multiple simultaneous loads
        guard !isLoading else {
            LoggingService.shared.logInfo("⚠️ Load already in progress, skipping", category: .general)
            return
        }

        isLoading = true
        hasError = false
        errorMessage = nil

        do {
            // Check for task cancellation
            if Task.isCancelled {
                isLoading = false
                return
            }

            // First, try to use preloaded articles if available
            if !isInitialLoad && !preloadedArticles.isEmpty {
                let addedCount = addPreloadedArticles()

                if addedCount > 0 {
                    isLoading = false
                    // Trigger background preload if needed
                    ensurePreloadBuffer()
                    return
                }
            }

            // Check for task cancellation before API call
            if Task.isCancelled {
                isLoading = false
                return
            }

            // Fetch new articles from API
            let newArticles = try await fetchArticlesFromAPI()

            // Check for task cancellation after API call
            if Task.isCancelled {
                isLoading = false
                return
            }

            // Filter and add unique articles
            let uniqueArticles = newArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }

            if uniqueArticles.isEmpty && !isInitialLoad {
                LoggingService.shared.logWarning("No new unique articles found", category: .general)
            }

            // Add articles to feed
            articles.append(contentsOf: uniqueArticles)
            uniqueArticles.forEach { fetchedArticleIds.insert($0.pageId) }

            isLoading = false

            // Preload images for newly fetched articles in background
            if !uniqueArticles.isEmpty {
                Task {
                    await articleRepository.preloadImages(for: uniqueArticles)
                }
            }

            // Start preloading in background
            ensurePreloadBuffer()

        } catch {
            // Don't handle error if task was cancelled
            if !Task.isCancelled {
                isLoading = false
                handleError(error)
            } else {
                isLoading = false
            }
        }
    }

    private func fetchArticlesFromAPI() async throws -> [WikipediaArticle] {
        let languageCode = articleLanguageManager.languageCode
        let topics = topicNormalizationService.getNormalizedTopicsFromUserDefaults()
        var categories = topicNormalizationService.getCategoriesForTopics(topics)
        
        // Ensure minimum 5 categories for better variety
        let minimumCategories = 5
        if categories.count < minimumCategories || topics.contains("All Topics") {
            // Get all available categories from all topics
            let allTopics = topicNormalizationService.getAllSupportedTopics()
            let allCategories = topicNormalizationService.getCategoriesForTopics(allTopics)
            
            // Add random categories to reach minimum
            let additionalNeeded = minimumCategories - categories.count
            let availableToAdd = allCategories.filter { !categories.contains($0) }
            let randomAdditions = Array(availableToAdd.shuffled().prefix(additionalNeeded))
            categories.append(contentsOf: randomAdditions)
        }
        
        // Always shuffle categories for randomness
        categories = Array(categories.shuffled())

        // Always use category-based fetch for better variety
        return try await retryManager.executeWithRetry(
            id: "fetchCategoryArticles",
            maxAttempts: 3
        ) {
            try await self.articleRepository.fetchCategoryBasedArticles(
                categories: categories,
                count: self.articlesPerBatch,
                languageCode: languageCode
            ).async()
        }
    }

    private func addPreloadedArticles() -> Int {
        let uniquePreloaded = preloadedArticles.filter { article in
            !fetchedArticleIds.contains(article.pageId)
        }

        let articlesToAdd = Array(uniquePreloaded.prefix(5))

        if !articlesToAdd.isEmpty {
            // Remove used articles from preload cache
            preloadedArticles.removeAll { article in
                articlesToAdd.contains { $0.pageId == article.pageId }
            }

            // Add to feed
            articles.append(contentsOf: articlesToAdd)
            articlesToAdd.forEach { fetchedArticleIds.insert($0.pageId) }

            LoggingService.shared.logInfo("✅ Added \(articlesToAdd.count) preloaded articles", category: .general)
        }

        return articlesToAdd.count
    }

    private func ensurePreloadBuffer() {
        // Only preload if buffer is low and not already preloading
        guard preloadedArticles.count < preloadThreshold && !isPreloading else { return }

        preloadTask?.cancel()
        preloadTask = Task {
            await preloadArticles()
        }
    }

    private func preloadArticles() async {
        guard !isPreloading else { return }

        isPreloading = true

        do {
            // Check for task cancellation
            if Task.isCancelled {
                isPreloading = false
                return
            }

            let languageCode = articleLanguageManager.languageCode
            let topics = topicNormalizationService.getNormalizedTopicsFromUserDefaults()
            var categories = topicNormalizationService.getCategoriesForTopics(topics)
            
            // Ensure minimum 5 categories for better variety
            let minimumCategories = 5
            if categories.count < minimumCategories || topics.contains("All Topics") {
                let allTopics = topicNormalizationService.getAllSupportedTopics()
                let allCategories = topicNormalizationService.getCategoriesForTopics(allTopics)
                
                let additionalNeeded = minimumCategories - categories.count
                let availableToAdd = allCategories.filter { !categories.contains($0) }
                let randomAdditions = Array(availableToAdd.shuffled().prefix(additionalNeeded))
                categories.append(contentsOf: randomAdditions)
            }
            
            // Always shuffle for randomness
            categories = Array(categories.shuffled())

            // Always use category-based preload for better variety
            let newArticles = await articleRepository.preloadCategoryBasedArticles(
                count: preloadBatchSize,
                categories: categories,
                languageCode: languageCode
            )

            // Check for task cancellation after fetching
            if Task.isCancelled {
                isPreloading = false
                return
            }

            // Filter unique articles
            let uniqueArticles = newArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }

            preloadedArticles.append(contentsOf: uniqueArticles)

            LoggingService.shared.logInfo("📦 Preloaded \(uniqueArticles.count) articles (buffer: \(preloadedArticles.count))", category: .general)

            // Preload images for better UX (only if not cancelled)
            if !Task.isCancelled {
                await articleRepository.preloadImages(for: uniqueArticles)
            }

        } catch {
            // Don't log error if task was cancelled
            if !Task.isCancelled {
                LoggingService.shared.logError("Preload failed: \(error)", category: .general)
            }
        }

        isPreloading = false
    }

    private func handleError(_ error: Error) {
        hasError = true

        if let repositoryError = error as? RepositoryError {
            errorMessage = repositoryError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }

        LoggingService.shared.logError("Feed load error: \(error)", category: .general)
    }

    // MARK: - Language and Topic Support

    func handleLanguageChange() {
        let newLanguageCode = articleLanguageManager.languageCode
        LoggingService.shared.logInfo("🌐 Language changed to: \(newLanguageCode)", category: .general)
        refresh()
    }

    func handleTopicsChange() {
        let topics = topicNormalizationService.getNormalizedTopicsFromUserDefaults()
        LoggingService.shared.logInfo("📝 Topics changed to: \(topics)", category: .general)
        refresh()
    }
}

// MARK: - Combine Extension for Async/Await
private extension AnyPublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasReceivedValue = false
            
            cancellable = self.first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            if !hasReceivedValue {
                                continuation.resume(throwing: NetworkError.noData)
                            }
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        hasReceivedValue = true
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}