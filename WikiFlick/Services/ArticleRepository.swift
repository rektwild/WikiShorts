import Foundation
import Combine
import UIKit

protocol ArticleRepositoryProtocol {
    func fetchRandomArticles(count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func fetchTopicBasedArticles(topics: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func fetchCategoryBasedArticles(categories: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func searchArticles(query: String, languageCode: String) -> AnyPublisher<[SearchResult], RepositoryError>
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, RepositoryError>
    func preloadArticles(count: Int, topics: [String], languageCode: String) async -> [WikipediaArticle]
    func preloadCategoryBasedArticles(count: Int, categories: [String], languageCode: String) async -> [WikipediaArticle]
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
    private var usedSearchTerms: Set<String> = []  // Track used search terms to ensure variety

    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        cacheManager: ArticleCacheManagerProtocol = ArticleCacheManager.shared
    ) {
        self.networkService = networkService
        self.cacheManager = cacheManager

        // Clear used terms when language or topics change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearUsedTerms),
            name: .articleLanguageChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearUsedTerms),
            name: .topicsChanged,
            object: nil
        )
    }

    @objc private func clearUsedTerms() {
        usedSearchTerms.removeAll()
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

    func fetchCategoryBasedArticles(categories: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        guard !categories.isEmpty, count > 0 else {
            return Just([])
                .setFailureType(to: RepositoryError.self)
                .eraseToAnyPublisher()
        }

        // If "All Topics" is selected, fall back to random articles
        if categories.contains("All Topics") {
            return fetchRandomArticles(count: count, languageCode: languageCode)
        }

        let publishers = categories.prefix(3).map { category in
            fetchArticlesFromCategory(category: category, count: max(1, count / categories.count), languageCode: languageCode)
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

        print("📚 preloadArticles called with topics: \(topics)")

        // Check for both "All Topics" and "all_topics"
        let hasAllTopics = topics.contains("All Topics") || topics.contains("all_topics")

        if hasAllTopics || topics.isEmpty {
            print("   ➜ Fetching random articles (hasAllTopics: \(hasAllTopics), isEmpty: \(topics.isEmpty))")
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
            print("   ➜ Fetching topic-based articles for: \(topics)")
            // Fetch topic-based articles
            for topic in topics.prefix(3) {
                let searchTerms = getSearchTermsForTopic(topic)
                // Filter out already used search terms and shuffle for variety
                let availableTerms = searchTerms.filter { !usedSearchTerms.contains($0) }.shuffled()
                let termsToUse = availableTerms.isEmpty ? searchTerms.shuffled() : availableTerms

                let articlesPerTopic = max(1, count / topics.count)

                for searchTerm in termsToUse.prefix(articlesPerTopic) {
                    usedSearchTerms.insert(searchTerm)  // Mark as used
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

    func preloadCategoryBasedArticles(count: Int, categories: [String], languageCode: String) async -> [WikipediaArticle] {
        var articles: [WikipediaArticle] = []

        print("📚 preloadCategoryBasedArticles called with categories: \(categories)")

        if categories.isEmpty {
            print("   ➜ No categories, fetching random articles")
            // If no categories, fall back to random articles
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
            print("   ➜ Fetching from categories: \(categories)")
            // Fetch from categories
            for category in categories.prefix(min(3, categories.count)) {
                let articlesPerCategory = max(1, count / min(categories.count, 3))

                do {
                    let categoryMembers = try await networkService.fetchCategoryMembers(
                        category: category,
                        languageCode: languageCode,
                        limit: articlesPerCategory * 2
                    ).async()

                    let selectedMembers = Array(categoryMembers.shuffled().prefix(articlesPerCategory))

                    for searchResult in selectedMembers {
                        do {
                            let article = try await networkService.fetchArticleDetails(
                                from: searchResult,
                                languageCode: languageCode
                            ).async()
                            articles.append(article)
                            cacheManager.cacheArticle(article)
                        } catch {
                            print("Failed to preload category article: \(error)")
                        }
                    }
                } catch {
                    print("Failed to fetch category members for \(category): \(error)")
                }
            }
        }

        return Array(articles.shuffled().prefix(count))
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
        // Handle both display names and keys
        let normalizedTopic = TopicManager.keyToDisplayMap[topic] ?? topic

        if normalizedTopic == "All Topics" || topic == "all_topics" {
            return fetchRandomArticles(count: count, languageCode: languageCode)
        }

        let searchTerms = getSearchTermsForTopic(topic)
        // Filter out already used search terms and shuffle for variety
        let availableTerms = searchTerms.filter { !usedSearchTerms.contains($0) }.shuffled()
        let termsToUse = availableTerms.isEmpty ? searchTerms.shuffled() : availableTerms

        let publishers = termsToUse.prefix(count).map { searchTerm in
            usedSearchTerms.insert(searchTerm)  // Mark as used
            return networkService.searchArticle(searchTerm: searchTerm, languageCode: languageCode)
                .mapError { RepositoryError.networkError($0) }
                .handleEvents(receiveOutput: { [weak self] article in
                    self?.cacheManager.cacheArticle(article)
                })
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }

    private func fetchArticlesFromCategory(category: String, count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        return networkService.fetchCategoryMembers(category: category, languageCode: languageCode, limit: count * 2)
            .mapError { RepositoryError.networkError($0) }
            .flatMap { searchResults -> AnyPublisher<[WikipediaArticle], RepositoryError> in
                guard !searchResults.isEmpty else {
                    // If category is empty, fall back to random articles
                    return self.fetchRandomArticles(count: count, languageCode: languageCode)
                }

                // Take a subset of results and fetch full article details
                let selectedResults = Array(searchResults.shuffled().prefix(count))
                let publishers = selectedResults.map { searchResult in
                    self.fetchArticleDetails(from: searchResult, languageCode: languageCode)
                }

                return Publishers.MergeMany(publishers)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func getSearchTermsForTopic(_ topic: String) -> [String] {
        // Handle both display names and keys
        let normalizedTopic = TopicManager.keyToDisplayMap[topic] ?? topic

        switch normalizedTopic {
        case "All Topics", "all_topics":
            return ["Random", "Knowledge", "Information", "Learning", "Education", "Facts", "Discovery", "Research",
                    "Theory", "Practice", "Study", "Analysis", "Exploration", "Understanding", "Insight"]
        case "General Reference", "general_reference":
            return ["Encyclopedia", "Reference", "Guide", "Manual", "Handbook", "Dictionary", "Index", "Catalog",
                    "Directory", "Glossary", "Thesaurus", "Bibliography", "Archive", "Documentation", "Resource"]
        case "Culture and the Arts", "culture_and_arts":
            return ["Art", "Music", "Literature", "Painting", "Cinema", "Theater", "Dance", "Sculpture",
                    "Poetry", "Opera", "Ballet", "Photography", "Architecture", "Design", "Museum", "Gallery",
                    "Performance", "Exhibition", "Artist", "Composer", "Writer", "Director", "Actor"]
        case "Geography and Places", "geography_and_places":
            return ["Country", "City", "Mountain", "Ocean", "River", "Continent", "Island", "Capital",
                    "Lake", "Desert", "Forest", "Valley", "Peninsula", "Bay", "Strait", "Region",
                    "Province", "State", "Nation", "Territory", "Landmark", "Monument", "Park"]
        case "Health and Fitness", "health_and_fitness":
            return ["Medicine", "Exercise", "Nutrition", "Health", "Disease", "Treatment", "Wellness", "Fitness",
                    "Hospital", "Doctor", "Surgery", "Therapy", "Vaccine", "Anatomy", "Psychology", "Mental Health",
                    "Diet", "Vitamin", "Sport Medicine", "Rehabilitation", "Prevention", "Diagnosis", "Pharmacy"]
        case "History and Events", "history_and_events":
            return ["War", "Revolution", "Empire", "Ancient", "Medieval", "Renaissance", "Civilization", "Battle",
                    "Dynasty", "Kingdom", "Republic", "Colony", "Independence", "Treaty", "Historical Figure",
                    "Archaeology", "Artifact", "Monument", "Timeline", "Era", "Age", "Period", "Century"]
        case "Human Activities", "human_activities":
            return ["Sport", "Game", "Recreation", "Hobby", "Competition", "Festival", "Celebration", "Activity",
                    "Olympics", "Championship", "Tournament", "League", "Team", "Player", "Coach", "Stadium",
                    "Entertainment", "Leisure", "Pastime", "Adventure", "Travel", "Tourism", "Event"]
        case "Mathematics and Logic", "mathematics_and_logic":
            return ["Mathematics", "Logic", "Statistics", "Geometry", "Algebra", "Calculus", "Number", "Formula",
                    "Theorem", "Equation", "Algorithm", "Probability", "Graph", "Function", "Matrix", "Vector",
                    "Proof", "Axiom", "Set Theory", "Topology", "Analysis", "Arithmetic", "Trigonometry"]
        case "Natural and Physical Sciences", "natural_and_physical_sciences":
            return ["Physics", "Chemistry", "Biology", "Science", "Nature", "Animal", "Plant", "Element",
                    "Molecule", "Atom", "Cell", "Evolution", "Genetics", "Ecology", "Astronomy", "Geology",
                    "Meteorology", "Oceanography", "Species", "Ecosystem", "Climate", "Energy", "Matter"]
        case "People and Self", "people_and_self":
            return ["Biography", "Person", "Leader", "Artist", "Scientist", "Writer", "Inventor", "Explorer",
                    "Philosopher", "Politician", "Musician", "Athlete", "Entrepreneur", "Nobel Prize", "Celebrity",
                    "Historical Figure", "Pioneer", "Activist", "Scholar", "Researcher", "Innovator", "Visionary"]
        case "Philosophy and Thinking", "philosophy_and_thinking":
            return ["Philosophy", "Ethics", "Logic", "Thought", "Mind", "Consciousness", "Wisdom", "Knowledge",
                    "Metaphysics", "Epistemology", "Aesthetics", "Morality", "Reason", "Truth", "Reality",
                    "Existence", "Free Will", "Philosopher", "School of Thought", "Theory", "Concept", "Idea"]
        case "Religion and Belief Systems", "religion_and_belief_systems":
            return ["Religion", "God", "Faith", "Belief", "Church", "Temple", "Prayer", "Sacred",
                    "Mythology", "Ritual", "Scripture", "Prophet", "Saint", "Pilgrimage", "Monastery",
                    "Spirituality", "Theology", "Divine", "Worship", "Ceremony", "Religious Text", "Doctrine"]
        case "Society and Social Sciences", "society_and_social_sciences":
            return ["Society", "Culture", "Politics", "Government", "Law", "Economics", "Social", "Community",
                    "Democracy", "Constitution", "Parliament", "Election", "Policy", "Institution", "Organization",
                    "Anthropology", "Sociology", "Psychology", "Education", "Justice", "Rights", "Movement"]
        case "Technology and Applied Sciences", "technology_and_applied_sciences":
            return ["Technology", "Computer", "Engineering", "Innovation", "Machine", "Internet", "Software", "Digital",
                    "Artificial Intelligence", "Robotics", "Biotechnology", "Nanotechnology", "Space Technology",
                    "Telecommunications", "Electronics", "Programming", "Database", "Network", "Cybersecurity",
                    "Automation", "Algorithm", "Hardware", "Application"]
        default:
            return ["Random", "Knowledge", "Information", "Learning", "Education", "Facts", "Discovery", "Research",
                    "Theory", "Practice", "Study", "Analysis", "Exploration", "Understanding", "Insight"]
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