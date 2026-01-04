import Foundation
import Combine
import UIKit

protocol ArticleRepositoryProtocol {

    func fetchTopicBasedArticles(topics: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func fetchCategoryBasedArticles(categories: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError>
    func searchArticles(query: String, languageCode: String) -> AnyPublisher<[SearchResult], RepositoryError>
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, RepositoryError>
    func preloadArticles(count: Int, topics: [String], languageCode: String) async -> [WikipediaArticle]
    func preloadCategoryBasedArticles(count: Int, categories: [String], languageCode: String) async -> [WikipediaArticle]
    func getCachedImage(for urlString: String) -> UIImage?
    func preloadImages(for articles: [WikipediaArticle]) async
    func fetchOnThisDayEvents(month: Int, day: Int, languageCode: String) -> AnyPublisher<[OnThisDayEvent], RepositoryError>
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
    
    private static let usedSearchTermsKey = "usedSearchTerms"
    private static let usedSearchTermsTimestampKey = "usedSearchTermsTimestamp"
    private static let ttlSeconds: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private func getUsedSearchTerms() -> Set<String> {
        // Check if TTL has expired
        if let timestamp = UserDefaults.standard.object(forKey: Self.usedSearchTermsTimestampKey) as? Date {
            if Date().timeIntervalSince(timestamp) > Self.ttlSeconds {
                // TTL expired, clear the terms
                clearUsedTerms()
                return []
            }
        }
        
        let array = UserDefaults.standard.stringArray(forKey: Self.usedSearchTermsKey) ?? []
        return Set(array)
    }
    
    private func addUsedSearchTerms(_ terms: [String]) {
        var current = getUsedSearchTerms()
        terms.forEach { current.insert($0) }
        UserDefaults.standard.set(Array(current), forKey: Self.usedSearchTermsKey)
        
        // Set timestamp if not already set
        if UserDefaults.standard.object(forKey: Self.usedSearchTermsTimestampKey) == nil {
            UserDefaults.standard.set(Date(), forKey: Self.usedSearchTermsTimestampKey)
        }
    }

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
        UserDefaults.standard.removeObject(forKey: Self.usedSearchTermsKey)
        UserDefaults.standard.removeObject(forKey: Self.usedSearchTermsTimestampKey)
    }
    

    
    func fetchTopicBasedArticles(topics: [String], count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        guard !topics.isEmpty, count > 0 else {
            return Just([])
                .setFailureType(to: RepositoryError.self)
                .eraseToAnyPublisher()
        }
        
        // If "All Topics" is selected, just use it as a keyword provider
        // No more random API fallback
        
        let publishers = topics.prefix(3).map { topic in
            fetchArticlesForTopicDSL(topic: topic, count: max(1, count / topics.count), languageCode: languageCode)
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

        // If "All Topics" is selected/exists in categories list, ignore it or handle as empty
        // In this case we just rely on the other categories or fallback to topic fetching if empty
        let filteredCategories = categories.filter { $0 != "All Topics" }
        
        if filteredCategories.isEmpty {
             return fetchTopicBasedArticles(topics: ["All Topics"], count: count, languageCode: languageCode)
        }

        // Use up to 5 categories for better variety
        let publishers = filteredCategories.prefix(5).map { category in
            fetchArticlesFromCategory(category: category, count: max(1, count / min(filteredCategories.count, 5)), languageCode: languageCode)
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

        // Check for both "All Topics" and "all_topics"
        let hasAllTopics = topics.contains("All Topics") || topics.contains("all_topics")
        let effectiveTopics = (hasAllTopics || topics.isEmpty) ? ["All Topics"] : topics

        for topic in effectiveTopics.prefix(3) {
            let searchTerms = getSearchTermsForTopic(topic)
            let usedTerms = getUsedSearchTerms()
            // Filter out already used search terms and shuffle for variety
            let availableTerms = searchTerms.filter { !usedTerms.contains($0) }.shuffled()
            let termsToUse = availableTerms.isEmpty ? searchTerms.shuffled() : availableTerms

            let articlesPerTopic = max(1, count / effectiveTopics.count)
            let termsForThisTopic = Array(termsToUse.prefix(articlesPerTopic))
            
            // Mark as used
            addUsedSearchTerms(termsForThisTopic)
            
            // Batch fetch for this topic's terms
            // 1. Search for each term to get pageIds
            // 2. Collate IDs and fetch details
            var pageIds: [Int] = []
            
            // Note: We can't easily batch the *searches* (different queries), but we can batch the *details*
            // However, since we are iterating terms, we are still doing N searches.
            // Optimization: Maybe search for combined terms "Term A | Term B"? Wikipedia support might be limited.
            // For now, let's keep N searches but batch the detail fetch if possible.
            // Actually, `searchArticle` (singular) was 1 search -> 1 detail fetch.
            // Now we want: N searches -> N results -> 1 detail fetch (batch).
            
            for searchTerm in termsForThisTopic {
                 do {
                     // Using searchWikipedia and select a random result for variety
                     let results = try await networkService.searchWikipedia(query: searchTerm, languageCode: languageCode).async()
                     if let result = results.prefix(5).randomElement() {
                         if let pageId = result.pageId {
                             pageIds.append(pageId)
                         }
                     }
                 } catch {
                     print("Failed to search term: \(searchTerm)")
                 }
            }
            
            if !pageIds.isEmpty {
                do {
                    let fetchedArticles = try await networkService.fetchArticles(pageIds: pageIds, languageCode: languageCode).async()
                    articles.append(contentsOf: fetchedArticles)
                    fetchedArticles.forEach { cacheManager.cacheArticle($0) }
                } catch {
                     print("Failed to batch fetch details: \(error)")
                }
            }
        }
        
        return articles.shuffled()
    }

    func preloadCategoryBasedArticles(count: Int, categories: [String], languageCode: String) async -> [WikipediaArticle] {
        var articles: [WikipediaArticle] = []
        
        let effectiveCategories = categories.filter { $0 != "All Topics" }

        if effectiveCategories.isEmpty {
            // Fallback to topic preload
             return await preloadArticles(count: count, topics: ["All Topics"], languageCode: languageCode)
        } else {
            // Fetch from up to 5 categories for better variety
            for category in effectiveCategories.prefix(min(5, effectiveCategories.count)) {
                let articlesPerCategory = max(1, count / min(effectiveCategories.count, 5))

                do {
                    let categoryMembers = try await networkService.fetchCategoryMembers(
                        category: category,
                        languageCode: languageCode,
                        limit: articlesPerCategory * 2
                    ).async()

                    let selectedMembers = Array(categoryMembers.shuffled().prefix(articlesPerCategory))
                    let pageIds = selectedMembers.compactMap { $0.pageId }
                    
                    if !pageIds.isEmpty {
                         let fetchedArticles = try await networkService.fetchArticles(pageIds: pageIds, languageCode: languageCode).async()
                         articles.append(contentsOf: fetchedArticles)
                         fetchedArticles.forEach { cacheManager.cacheArticle($0) }
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
        // Sequential loading with throttling to avoid rate limiting (429 errors)
        for article in articles {
            if let imageURLString = article.imageURL {
                _ = await cacheManager.preloadImage(from: imageURLString)
                // Small delay between requests to avoid rate limiting
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    // MARK: - Private Methods
    


    private func fetchArticlesForTopicDSL(topic: String, count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        let searchTerms = getSearchTermsForTopic(topic)
        let usedTerms = getUsedSearchTerms()
        // Filter out already used search terms and shuffle for variety
        let availableTerms = searchTerms.filter { !usedTerms.contains($0) }.shuffled()
        let termsToUse = availableTerms.isEmpty ? searchTerms.shuffled() : availableTerms
        let selectedTerms = Array(termsToUse.prefix(count))
        
        addUsedSearchTerms(selectedTerms)
        
        // 1. Convert terms to search publishers
        let searchPublishers = selectedTerms.map { term in
             networkService.searchWikipedia(query: term, languageCode: languageCode)
                 .mapError { RepositoryError.networkError($0) }
                 .map { results in results.prefix(5).randomElement() } // Take random result from top 5 for variety
                 .replaceError(with: nil)
                 .setFailureType(to: RepositoryError.self)
        }
        
        // 2. Run searches, collect IDs, then batch fetch details
        return Publishers.MergeMany(searchPublishers)
            .collect()
            .flatMap { searchResults -> AnyPublisher<[WikipediaArticle], RepositoryError> in
                let validResults = searchResults.compactMap { $0 }
                let pageIds = validResults.compactMap { $0.pageId }
                
                if pageIds.isEmpty {
                    return Just([]).setFailureType(to: RepositoryError.self).eraseToAnyPublisher()
                }
                
                return self.networkService.fetchArticles(pageIds: pageIds, languageCode: languageCode)
                    .mapError { RepositoryError.networkError($0) }
                    .handleEvents(receiveOutput: { [weak self] articles in
                         articles.forEach { self?.cacheManager.cacheArticle($0) }
                    })
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func fetchArticlesFromCategory(category: String, count: Int, languageCode: String) -> AnyPublisher<[WikipediaArticle], RepositoryError> {
        return networkService.fetchCategoryMembers(category: category, languageCode: languageCode, limit: count * 2)
            .mapError { RepositoryError.networkError($0) }
            .flatMap { searchResults -> AnyPublisher<[WikipediaArticle], RepositoryError> in
                guard !searchResults.isEmpty else {
                   return Just([]).setFailureType(to: RepositoryError.self).eraseToAnyPublisher()
                }

                // Take a subset of results and fetch full article details using BATCH fetch
                let selectedResults = Array(searchResults.shuffled().prefix(count))
                let pageIds = selectedResults.compactMap { $0.pageId }
                
                guard !pageIds.isEmpty else {
                    return Just([]).setFailureType(to: RepositoryError.self).eraseToAnyPublisher()
                }

                return self.networkService.fetchArticles(pageIds: pageIds, languageCode: languageCode)
                    .mapError { RepositoryError.networkError($0) }
                    .handleEvents(receiveOutput: { [weak self] articles in
                        articles.forEach { self?.cacheManager.cacheArticle($0) }
                    })
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
                    "Theory", "Practice", "Study", "Analysis", "Exploration", "Understanding", "Insight",
                    "Wisdom", "Science", "History", "Culture", "Nature", "Technology", "Art", "Music",
                    "Literature", "Philosophy", "Geography", "Mathematics", "Medicine", "Engineering",
                    "Architecture", "Astronomy", "Biology", "Chemistry", "Physics", "Psychology",
                    "Sociology", "Economics", "Politics", "Law", "Religion", "Language", "Mythology",
                    "Folklore", "Sports", "Games", "Food", "Fashion", "Transportation", "Communication",
                    "Energy", "Environment", "Space", "Ocean", "Mountain", "River", "Forest", "Desert"]
        case "General Reference", "general_reference":
            return ["Encyclopedia", "Reference", "Guide", "Manual", "Handbook", "Dictionary", "Index", "Catalog",
                    "Directory", "Glossary", "Thesaurus", "Bibliography", "Archive", "Documentation", "Resource",
                    "Almanac", "Atlas", "Compendium", "Database", "Lexicon", "Primer", "Sourcebook", "Textbook",
                    "Yearbook", "Periodical", "Journal", "Magazine", "Newsletter", "Bulletin", "Report",
                    "White Paper", "Thesis", "Dissertation", "Monograph", "Treatise", "Survey", "Review",
                    "Abstract", "Summary", "Synopsis", "Outline", "Framework", "Model", "Template", "Standard",
                    "Specification", "Protocol", "Procedure", "Methodology", "Best Practice", "Case Study"]
        case "Culture and the Arts", "culture_and_arts":
            return ["Art", "Music", "Literature", "Painting", "Cinema", "Theater", "Dance", "Sculpture",
                    "Poetry", "Opera", "Ballet", "Photography", "Architecture", "Design", "Museum", "Gallery",
                    "Performance", "Exhibition", "Artist", "Composer", "Writer", "Director", "Actor",
                    "Symphony", "Orchestra", "Jazz", "Rock", "Pop", "Classical Music", "Folk Music",
                    "Renaissance Art", "Modern Art", "Contemporary Art", "Abstract Art", "Impressionism",
                    "Surrealism", "Cubism", "Baroque", "Gothic", "Romanticism", "Realism", "Expressionism",
                    "Novel", "Short Story", "Drama", "Comedy", "Tragedy", "Film", "Documentary", "Animation",
                    "Graphic Novel", "Comic", "Manga", "Anime", "Street Art", "Graffiti", "Craft", "Pottery"]
        case "Geography and Places", "geography_and_places":
            return ["Country", "City", "Mountain", "Ocean", "River", "Continent", "Island", "Capital",
                    "Lake", "Desert", "Forest", "Valley", "Peninsula", "Bay", "Strait", "Region",
                    "Province", "State", "Nation", "Territory", "Landmark", "Monument", "Park",
                    "Volcano", "Glacier", "Canyon", "Plateau", "Plain", "Rainforest", "Tundra", "Savanna",
                    "Archipelago", "Atoll", "Reef", "Waterfall", "Cave", "Cliff", "Beach", "Harbor",
                    "Port", "Bridge", "Tower", "Castle", "Palace", "Temple", "Cathedral", "Mosque",
                    "Pyramid", "Ruins", "UNESCO", "World Heritage", "National Park", "Nature Reserve",
                    "Biosphere", "Ecosystem", "Climate Zone", "Time Zone", "Border", "Capital City"]
        case "Health and Fitness", "health_and_fitness":
            return ["Medicine", "Exercise", "Nutrition", "Health", "Disease", "Treatment", "Wellness", "Fitness",
                    "Hospital", "Doctor", "Surgery", "Therapy", "Vaccine", "Anatomy", "Psychology", "Mental Health",
                    "Diet", "Vitamin", "Sport Medicine", "Rehabilitation", "Prevention", "Diagnosis", "Pharmacy",
                    "Cardiology", "Neurology", "Oncology", "Pediatrics", "Geriatrics", "Dermatology", "Ophthalmology",
                    "Dentistry", "Psychiatry", "Immunology", "Endocrinology", "Gastroenterology", "Pulmonology",
                    "Yoga", "Meditation", "Mindfulness", "Sleep", "Stress", "Anxiety", "Depression", "Addiction",
                    "Physical Therapy", "Occupational Therapy", "Speech Therapy", "Chiropractic", "Acupuncture",
                    "Homeopathy", "Ayurveda", "Traditional Medicine", "Public Health", "Epidemiology", "Genetics"]
        case "History and Events", "history_and_events":
            return ["War", "Revolution", "Empire", "Ancient", "Medieval", "Renaissance", "Civilization", "Battle",
                    "Dynasty", "Kingdom", "Republic", "Colony", "Independence", "Treaty", "Historical Figure",
                    "Archaeology", "Artifact", "Monument", "Timeline", "Era", "Age", "Period", "Century",
                    "Bronze Age", "Iron Age", "Stone Age", "Ice Age", "Middle Ages", "Dark Ages", "Enlightenment",
                    "Industrial Revolution", "French Revolution", "American Revolution", "World War", "Cold War",
                    "Civil War", "Crusades", "Colonialism", "Imperialism", "Nationalism", "Communism", "Fascism",
                    "Democracy", "Monarchy", "Feudalism", "Slavery", "Abolition", "Civil Rights", "Women's Rights",
                    "Ancient Egypt", "Ancient Greece", "Ancient Rome", "Byzantine", "Ottoman", "Persian Empire",
                    "Mongol Empire", "Aztec", "Maya", "Inca", "Viking", "Samurai", "Knights", "Pharaoh"]
        case "Human Activities", "human_activities":
            return ["Sport", "Game", "Recreation", "Hobby", "Competition", "Festival", "Celebration", "Activity",
                    "Olympics", "Championship", "Tournament", "League", "Team", "Player", "Coach", "Stadium",
                    "Entertainment", "Leisure", "Pastime", "Adventure", "Travel", "Tourism", "Event",
                    "Football", "Basketball", "Tennis", "Golf", "Swimming", "Running", "Cycling", "Boxing",
                    "Wrestling", "Martial Arts", "Gymnastics", "Skiing", "Surfing", "Skating", "Chess", "Poker",
                    "Video Games", "Board Games", "Card Games", "Puzzle", "Trivia", "Quiz", "Escape Room",
                    "Camping", "Hiking", "Climbing", "Fishing", "Hunting", "Gardening", "Cooking", "Baking",
                    "Photography", "Painting", "Drawing", "Knitting", "Sewing", "Woodworking", "Collecting"]
        case "Mathematics and Logic", "mathematics_and_logic":
            return ["Mathematics", "Logic", "Statistics", "Geometry", "Algebra", "Calculus", "Number", "Formula",
                    "Theorem", "Equation", "Algorithm", "Probability", "Graph", "Function", "Matrix", "Vector",
                    "Proof", "Axiom", "Set Theory", "Topology", "Analysis", "Arithmetic", "Trigonometry",
                    "Prime Number", "Fibonacci", "Pi", "Infinity", "Zero", "Fraction", "Decimal", "Percentage",
                    "Polynomial", "Logarithm", "Exponential", "Derivative", "Integral", "Differential", "Linear",
                    "Quadratic", "Cubic", "Complex Number", "Imaginary Number", "Rational", "Irrational",
                    "Pythagorean", "Euclidean", "Non-Euclidean", "Fractal", "Chaos Theory", "Game Theory",
                    "Cryptography", "Number Theory", "Combinatorics", "Graph Theory", "Boolean", "Binary"]
        case "Natural and Physical Sciences", "natural_and_physical_sciences":
            return ["Physics", "Chemistry", "Biology", "Science", "Nature", "Animal", "Plant", "Element",
                    "Molecule", "Atom", "Cell", "Evolution", "Genetics", "Ecology", "Astronomy", "Geology",
                    "Meteorology", "Oceanography", "Species", "Ecosystem", "Climate", "Energy", "Matter",
                    "Quantum", "Relativity", "Gravity", "Electromagnetism", "Nuclear", "Particle", "Wave",
                    "Light", "Sound", "Heat", "Thermodynamics", "Mechanics", "Optics", "Acoustics", "Electron",
                    "Proton", "Neutron", "Photon", "Quark", "DNA", "RNA", "Protein", "Enzyme", "Hormone",
                    "Virus", "Bacteria", "Fungus", "Mammal", "Bird", "Reptile", "Fish", "Insect", "Amphibian",
                    "Dinosaur", "Fossil", "Extinction", "Biodiversity", "Conservation", "Photosynthesis"]
        case "People and Self", "people_and_self":
            return ["Biography", "Person", "Leader", "Artist", "Scientist", "Writer", "Inventor", "Explorer",
                    "Philosopher", "Politician", "Musician", "Athlete", "Entrepreneur", "Nobel Prize", "Celebrity",
                    "Historical Figure", "Pioneer", "Activist", "Scholar", "Researcher", "Innovator", "Visionary",
                    "President", "King", "Queen", "Emperor", "Prime Minister", "General", "Admiral", "Astronaut",
                    "Pilot", "Captain", "Doctor", "Professor", "Teacher", "Engineer", "Architect", "Designer",
                    "Painter", "Sculptor", "Photographer", "Film Director", "Actor", "Singer", "Dancer", "Chef",
                    "Author", "Poet", "Journalist", "Editor", "Publisher", "Mathematician", "Physicist", "Chemist",
                    "Biologist", "Psychologist", "Economist", "Historian", "Anthropologist", "Archaeologist"]
        case "Philosophy and Thinking", "philosophy_and_thinking":
            return ["Philosophy", "Ethics", "Logic", "Thought", "Mind", "Consciousness", "Wisdom", "Knowledge",
                    "Metaphysics", "Epistemology", "Aesthetics", "Morality", "Reason", "Truth", "Reality",
                    "Existence", "Free Will", "Philosopher", "School of Thought", "Theory", "Concept", "Idea",
                    "Stoicism", "Epicureanism", "Platonism", "Aristotelianism", "Skepticism", "Cynicism", "Nihilism",
                    "Existentialism", "Rationalism", "Empiricism", "Idealism", "Materialism", "Dualism", "Monism",
                    "Pragmatism", "Utilitarianism", "Deontology", "Virtue Ethics", "Social Contract", "Natural Law",
                    "Determinism", "Libertarianism", "Compatibilism", "Solipsism", "Phenomenology", "Hermeneutics",
                    "Dialectics", "Socratic Method", "Critical Thinking", "Logical Fallacy", "Paradox", "Dilemma"]
        case "Religion and Belief Systems", "religion_and_belief_systems":
            return ["Religion", "God", "Faith", "Belief", "Church", "Temple", "Prayer", "Sacred",
                    "Mythology", "Ritual", "Scripture", "Prophet", "Saint", "Pilgrimage", "Monastery",
                    "Spirituality", "Theology", "Divine", "Worship", "Ceremony", "Religious Text", "Doctrine",
                    "Christianity", "Islam", "Judaism", "Buddhism", "Hinduism", "Sikhism", "Taoism", "Shinto",
                    "Confucianism", "Zoroastrianism", "Jainism", "Baha'i", "Animism", "Shamanism", "Paganism",
                    "Bible", "Quran", "Torah", "Vedas", "Tripitaka", "Guru Granth Sahib", "Tao Te Ching",
                    "Jesus", "Muhammad", "Buddha", "Moses", "Krishna", "Confucius", "Lao Tzu", "Guru Nanak",
                    "Heaven", "Hell", "Reincarnation", "Karma", "Nirvana", "Salvation", "Sin", "Redemption"]
        case "Society and Social Sciences", "society_and_social_sciences":
            return ["Society", "Culture", "Politics", "Government", "Law", "Economics", "Social", "Community",
                    "Democracy", "Constitution", "Parliament", "Election", "Policy", "Institution", "Organization",
                    "Anthropology", "Sociology", "Psychology", "Education", "Justice", "Rights", "Movement",
                    "Capitalism", "Socialism", "Communism", "Liberalism", "Conservatism", "Feminism", "Environmentalism",
                    "Human Rights", "Civil Rights", "Voting Rights", "Freedom of Speech", "Privacy", "Equality",
                    "Poverty", "Inequality", "Discrimination", "Racism", "Sexism", "Immigration", "Refugee",
                    "Globalization", "Urbanization", "Industrialization", "Modernization", "Democratization",
                    "United Nations", "European Union", "NATO", "World Bank", "IMF", "NGO", "Nonprofit"]
        case "Technology and Applied Sciences", "technology_and_applied_sciences":
            return ["Technology", "Computer", "Engineering", "Innovation", "Machine", "Internet", "Software", "Digital",
                    "Artificial Intelligence", "Robotics", "Biotechnology", "Nanotechnology", "Space Technology",
                    "Telecommunications", "Electronics", "Programming", "Database", "Network", "Cybersecurity",
                    "Automation", "Algorithm", "Hardware", "Application",
                    "Smartphone", "Laptop", "Tablet", "Server", "Cloud Computing", "Big Data", "Machine Learning",
                    "Deep Learning", "Neural Network", "Blockchain", "Cryptocurrency", "Virtual Reality", "Augmented Reality",
                    "3D Printing", "Drone", "Electric Vehicle", "Solar Energy", "Wind Energy", "Nuclear Energy",
                    "Satellite", "GPS", "WiFi", "Bluetooth", "5G", "Fiber Optic", "Semiconductor", "Microprocessor",
                    "Operating System", "Web Browser", "Social Media", "Search Engine", "E-commerce", "Streaming"]
        default:
            return ["Random", "Knowledge", "Information", "Learning", "Education", "Facts", "Discovery", "Research",
                    "Theory", "Practice", "Study", "Analysis", "Exploration", "Understanding", "Insight",
                    "Wisdom", "Science", "History", "Culture", "Nature", "Technology", "Art", "Music",
                    "Literature", "Philosophy", "Geography", "Mathematics", "Medicine", "Engineering",
                    "Architecture", "Astronomy", "Biology", "Chemistry", "Physics", "Psychology",
                    "Sociology", "Economics", "Politics", "Law", "Religion", "Language", "Mythology",
                    "Folklore", "Sports", "Games", "Food", "Fashion", "Transportation", "Communication"]
        }
    }
    
    func fetchOnThisDayEvents(month: Int, day: Int, languageCode: String) -> AnyPublisher<[OnThisDayEvent], RepositoryError> {
        return networkService.fetchOnThisDayEvents(month: month, day: day, languageCode: languageCode)
            .mapError { RepositoryError.networkError($0) }
            .map { $0.events }
            .eraseToAnyPublisher()
    }
}

// MARK: - Publisher Extension for async/await
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var hasReceivedValue = false
            
            cancellable = first()
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    case .finished:
                        if !hasReceivedValue {
                            continuation.resume(throwing: NetworkError.noData)
                        }
                    }
                    cancellable?.cancel()
                }, receiveValue: { value in
                    hasReceivedValue = true
                    continuation.resume(returning: value)
                })
        }
    }
}