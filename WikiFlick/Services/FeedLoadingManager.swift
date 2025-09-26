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
        activeFetchTask?.cancel()
        preloadTask?.cancel()

        articles.removeAll()
        preloadedArticles.removeAll()
        fetchedArticleIds.removeAll()
        isLoading = false
        isPreloading = false
        hasError = false
        errorMessage = nil
    }

    /// Refresh feed with new content
    func refresh() {
        reset()
        loadArticles(isInitialLoad: true)
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

            // Fetch new articles from API
            let newArticles = try await fetchArticlesFromAPI()

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

            // Start preloading in background
            ensurePreloadBuffer()

        } catch {
            isLoading = false
            handleError(error)
        }
    }

    private func fetchArticlesFromAPI() async throws -> [WikipediaArticle] {
        let languageCode = articleLanguageManager.languageCode
        let topics = topicNormalizationService.getNormalizedTopicsFromUserDefaults()
        let categories = topicNormalizationService.getCategoriesForTopics(topics)

        // Try category-based fetch first, then fall back to topic-based
        if !categories.isEmpty && !topics.contains("All Topics") {
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
        } else {
            return try await retryManager.executeWithRetry(
                id: "fetchTopicArticles",
                maxAttempts: 3
            ) {
                try await self.articleRepository.fetchTopicBasedArticles(
                    topics: topics,
                    count: self.articlesPerBatch,
                    languageCode: languageCode
                ).async()
            }
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
            let languageCode = articleLanguageManager.languageCode
            let topics = topicNormalizationService.getNormalizedTopicsFromUserDefaults()
            let categories = topicNormalizationService.getCategoriesForTopics(topics)

            let newArticles: [WikipediaArticle]

            if !categories.isEmpty && !topics.contains("All Topics") {
                newArticles = await articleRepository.preloadCategoryBasedArticles(
                    count: preloadBatchSize,
                    categories: categories,
                    languageCode: languageCode
                )
            } else {
                newArticles = await articleRepository.preloadArticles(
                    count: preloadBatchSize,
                    topics: topics,
                    languageCode: languageCode
                )
            }

            // Filter unique articles
            let uniqueArticles = newArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }

            preloadedArticles.append(contentsOf: uniqueArticles)

            LoggingService.shared.logInfo("📦 Preloaded \(uniqueArticles.count) articles (buffer: \(preloadedArticles.count))", category: .general)

            // Preload images for better UX
            await articleRepository.preloadImages(for: uniqueArticles)

        } catch {
            LoggingService.shared.logError("Preload failed: \(error)", category: .general)
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
            cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    continuation.resume(returning: value)
                }
            )
        }
    }
}