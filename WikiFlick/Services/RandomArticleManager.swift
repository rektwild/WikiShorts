//
//  RandomArticleManager.swift
//  WikiFlick
//
//  Manages truly random article loading (ignores user topic preferences)
//

import Foundation
import Combine

@MainActor
class RandomArticleManager: ObservableObject {
    static let shared = RandomArticleManager()
    
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
    private let retryManager = RetryManager()
    
    // Configuration
    private let articlesPerBatch = 10
    private let preloadBatchSize = 15
    private let preloadThreshold = 20
    
    private init(articleRepository: ArticleRepositoryProtocol = ArticleRepository()) {
        self.articleRepository = articleRepository
    }
    
    // MARK: - Public Methods
    
    func loadArticles(isInitialLoad: Bool = false) {
        activeFetchTask?.cancel()
        
        activeFetchTask = Task {
            await performLoad(isInitialLoad: isInitialLoad)
        }
    }
    
    func reset() {
        activeFetchTask?.cancel()
        preloadTask?.cancel()
        
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            articles.removeAll()
            preloadedArticles.removeAll()
            fetchedArticleIds.removeAll()
            isLoading = false
            isPreloading = false
            hasError = false
            errorMessage = nil
        }
    }
    
    func refresh() {
        activeFetchTask?.cancel()
        preloadTask?.cancel()
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            articles.removeAll()
            preloadedArticles.removeAll()
            fetchedArticleIds.removeAll()
            isLoading = false
            isPreloading = false
            hasError = false
            errorMessage = nil
            
            loadArticles(isInitialLoad: true)
        }
    }
    
    // MARK: - Private Methods
    
    private func performLoad(isInitialLoad: Bool) async {
        guard !isLoading else {
            LoggingService.shared.logInfo("⚠️ Random load already in progress, skipping", category: .general)
            return
        }
        
        isLoading = true
        hasError = false
        errorMessage = nil
        
        do {
            if Task.isCancelled {
                isLoading = false
                return
            }
            
            if !isInitialLoad && !preloadedArticles.isEmpty {
                let addedCount = addPreloadedArticles()
                
                if addedCount > 0 {
                    isLoading = false
                    ensurePreloadBuffer()
                    return
                }
            }
            
            if Task.isCancelled {
                isLoading = false
                return
            }
            
            // Fetch random articles using "All Topics" to get variety from all categories
            let newArticles = try await fetchRandomArticlesFromAPI()
            
            if Task.isCancelled {
                isLoading = false
                return
            }
            
            let uniqueArticles = newArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }
            
            if uniqueArticles.isEmpty && !isInitialLoad {
                LoggingService.shared.logWarning("No new unique random articles found", category: .general)
            }
            
            articles.append(contentsOf: uniqueArticles)
            uniqueArticles.forEach { fetchedArticleIds.insert($0.pageId) }
            
            isLoading = false
            
            // Preload images for newly fetched articles in background
            if !uniqueArticles.isEmpty {
                Task {
                    await articleRepository.preloadImages(for: uniqueArticles)
                }
            }
            
            ensurePreloadBuffer()
            
        } catch {
            if !Task.isCancelled {
                isLoading = false
                handleError(error)
            } else {
                isLoading = false
            }
        }
    }
    
    private func fetchRandomArticlesFromAPI() async throws -> [WikipediaArticle] {
        let languageCode = articleLanguageManager.languageCode
        
        // Always use "All Topics" to get random articles from all categories
        return try await retryManager.executeWithRetry(
            id: "fetchRandomArticles",
            maxAttempts: 3
        ) {
            try await self.articleRepository.fetchTopicBasedArticles(
                topics: ["All Topics"],
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
            preloadedArticles.removeAll { article in
                articlesToAdd.contains { $0.pageId == article.pageId }
            }
            
            articles.append(contentsOf: articlesToAdd)
            articlesToAdd.forEach { fetchedArticleIds.insert($0.pageId) }
            
            LoggingService.shared.logInfo("✅ Added \(articlesToAdd.count) preloaded random articles", category: .general)
        }
        
        return articlesToAdd.count
    }
    
    private func ensurePreloadBuffer() {
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
            if Task.isCancelled {
                isPreloading = false
                return
            }
            
            let languageCode = articleLanguageManager.languageCode
            
            // Always use "All Topics" for truly random content
            let newArticles = await articleRepository.preloadArticles(
                count: preloadBatchSize,
                topics: ["All Topics"],
                languageCode: languageCode
            )
            
            if Task.isCancelled {
                isPreloading = false
                return
            }
            
            let uniqueArticles = newArticles.filter { article in
                !fetchedArticleIds.contains(article.pageId)
            }
            
            preloadedArticles.append(contentsOf: uniqueArticles)
            
            LoggingService.shared.logInfo("📦 Preloaded \(uniqueArticles.count) random articles (buffer: \(preloadedArticles.count))", category: .general)
            
            if !Task.isCancelled {
                await articleRepository.preloadImages(for: uniqueArticles)
            }
            
        } catch {
            if !Task.isCancelled {
                LoggingService.shared.logError("Random preload failed: \(error)", category: .general)
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
        
        LoggingService.shared.logError("Random article load error: \(error)", category: .general)
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
