import Foundation
import Combine
import UIKit

protocol ArticleRepositoryProtocol {
    func fetchRandomArticles(count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func fetchTopicBasedArticles(topics: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func searchArticles(query: String, languageCode: String) -> AnyPublisher<[SearchResult], RepositoryError>
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, RepositoryError>
    func preloadArticles(count: Int, topics: [String], languageCode: String) async -> [WikipediaArticle]
    func getCachedImage(for urlString: String) -> UIImage?
    func preloadImages(for articles: [WikipediaArticle]) async
}

enum RepositoryError: Error, LocalizedError {
    case networkError(NetworkError)
    case cacheError(String)
    case validationError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let networkError):
            return networkError.localizedDescription
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknownError(let message):
            return message
        }
    }
}

class ArticleRepository: ArticleRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheManager: ArticleCacheManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        cacheManager: ArticleCacheManagerProtocol = ArticleCacheManager.shared
    ) {
        self.networkService = networkService
        self.cacheManager = cacheManager
    }
    
    func fetchRandomArticles(count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        guard count > 0 else {
            return Just([])
                .setFailureType(to: RepositoryError.self)
                .eraseToAnyPublisher()
        }
        
        let publishers = (0..<count).map { _ in
            networkService.fetchRandomArticle(languageCode: languageCode)
                .mapError { RepositoryError.networkError($0) }
                .handleEvents(receiveOutput: { [weak self] article in
                    self?.cacheManager.cacheArticle(article)
                })
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    func fetchTopicBasedArticles(topics: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        guard !topics.isEmpty, count > 0 else {
            return Just([])
                .setFailureType(to: RepositoryError.self)
                .eraseToAnyPublisher()
        }
        
        if topics.contains("All Topics") || topics.isEmpty {
            return fetchRandomArticles(count: count, languageCode: languageCode)
        }
        
        let publishers = topics.prefix(3).map { topic in
            fetchArticlesForTopic(topic: topic, count: max(1, count / topics.count), languageCode: languageCode)
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { articleArrays in
                let flattenedArticles = articleArrays.flatMap { $0 }
                return Array(flattenedArticles.shuffled().prefix(count))
            }
            .eraseToAnyPublisher()
    }
    
    func searchArticles(query: String, languageCode: String) -> AnyPublisher<[SearchResult], RepositoryError> {
        return networkService.searchWikipedia(query: query, languageCode: languageCode)
            .mapError { RepositoryError.networkError($0) }
            .eraseToAnyPublisher()
    }
    
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, RepositoryError> {
        // Check cache first using actual pageId from search result
        if let pageId = searchResult.pageId,
           let cachedArticle = cacheManager.getCachedArticle(pageId: pageId) {
            return Just(cachedArticle)
                .setFailureType(to: RepositoryError.self)
                .eraseToAnyPublisher()
        }
        
        return networkService.fetchArticleDetails(from: searchResult, languageCode: languageCode)
            .mapError { RepositoryError.networkError($0) }
            .handleEvents(receiveOutput: { [weak self] article in
                self?.cacheManager.cacheArticle(article)
            })
            .eraseToAnyPublisher()
    }
    
    func preloadArticles(count: Int, topics: [String], languageCode: String) async -> [WikipediaArticle] {
        var articles: [WikipediaArticle] = []
        
        if topics.contains("All Topics") || topics.isEmpty {
            // Fetch random articles
            for _ in 0..<count {
                do {
                    let article = try await networkService.fetchRandomArticle(languageCode: languageCode)
                        .async()
                    articles.append(article)
                    cacheManager.cacheArticle(article)
                } catch {
                    print("Failed to preload random article: \(error)")
                }
            }
        } else {
            // Fetch topic-based articles
            for topic in topics.prefix(3) {
                let searchTerms = getSearchTermsForTopic(topic)
                let articlesPerTopic = max(1, count / topics.count)
                
                for searchTerm in searchTerms.prefix(articlesPerTopic) {
                    do {
                        let article = try await networkService.searchArticle(searchTerm: searchTerm, languageCode: languageCode)
                            .async()
                        articles.append(article)
                        cacheManager.cacheArticle(article)
                    } catch {
                        print("Failed to preload topic article: \(error)")
                    }
                }
            }
        }
        
        return articles.shuffled()
    }
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return cacheManager.getCachedImage(for: urlString)
    }
    
    func preloadImages(for articles: [WikipediaArticle]) async {
        await withTaskGroup(of: Void.self) { group in
            for article in articles {
                if let imageURLString = article.imageURL {
                    group.addTask { [weak self] in
                        _ = await self?.cacheManager.preloadImage(from: imageURLString)
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchArticlesForTopic(topic: String, count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        if topic == "All Topics" {
            return fetchRandomArticles(count: count, languageCode: languageCode)
        }
        
        let searchTerms = getSearchTermsForTopic(topic)
        let publishers = searchTerms.prefix(count).map { searchTerm in
            networkService.searchArticle(searchTerm: searchTerm, languageCode: languageCode)
                .mapError { RepositoryError.networkError($0) }
                .handleEvents(receiveOutput: { [weak self] article in
                    self?.cacheManager.cacheArticle(article)
                })
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    private func getSearchTermsForTopic(_ topic: String) -> [String] {
        switch topic {
        case "All Topics":
            return ["Random", "Knowledge", "Information", "Learning", "Education", "Facts", "Discovery", "Research"]
        case "General Reference":
            return ["Encyclopedia", "Reference", "Guide", "Manual", "Handbook", "Dictionary", "Index", "Catalog"]
        case "Culture and the Arts":
            return ["Art", "Music", "Literature", "Painting", "Cinema", "Theater", "Dance", "Sculpture"]
        case "Geography and Places":
            return ["Country", "City", "Mountain", "Ocean", "River", "Continent", "Island", "Capital"]
        case "Health and Fitness":
            return ["Medicine", "Exercise", "Nutrition", "Health", "Disease", "Treatment", "Wellness", "Fitness"]
        case "History and Events":
            return ["War", "Revolution", "Empire", "Ancient", "Medieval", "Renaissance", "Civilization", "Battle"]
        case "Human Activities":
            return ["Sport", "Game", "Recreation", "Hobby", "Competition", "Festival", "Celebration", "Activity"]
        case "Mathematics and Logic":
            return ["Mathematics", "Logic", "Statistics", "Geometry", "Algebra", "Calculus", "Number", "Formula"]
        case "Natural and Physical Sciences":
            return ["Physics", "Chemistry", "Biology", "Science", "Nature", "Animal", "Plant", "Element"]
        case "People and Self":
            return ["Biography", "Person", "Leader", "Artist", "Scientist", "Writer", "Inventor", "Explorer"]
        case "Philosophy and Thinking":
            return ["Philosophy", "Ethics", "Logic", "Thought", "Mind", "Consciousness", "Wisdom", "Knowledge"]
        case "Religion and Belief Systems":
            return ["Religion", "God", "Faith", "Belief", "Church", "Temple", "Prayer", "Sacred"]
        case "Society and Social Sciences":
            return ["Society", "Culture", "Politics", "Government", "Law", "Economics", "Social", "Community"]
        case "Technology and Applied Sciences":
            return ["Technology", "Computer", "Engineering", "Innovation", "Machine", "Internet", "Software", "Digital"]
        default:
            return ["Random", "Knowledge", "Information", "Learning", "Education", "Facts", "Discovery", "Research"]
        }
    }
}

// MARK: - Publisher Extension for async/await
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = first()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    case .finished:
                        break
                    }
                    cancellable?.cancel()
                }, receiveValue: { value in
                    continuation.resume(returning: value)
                })
        }
    }
}