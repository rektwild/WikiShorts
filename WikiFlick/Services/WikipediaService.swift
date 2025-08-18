import Foundation
import Combine

class WikipediaService: ObservableObject {
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
    private var imageCache = NSCache<NSString, UIImage>()
    
    private let problematicLanguages: Set<String> = ["lzh", "yue"]
    private let requestTimeout: TimeInterval = 15.0
    
    // Track current settings to detect changes
    private var currentLanguage: String = ""
    private var currentTopics: [String] = []
    
    init() {
        // Initialize current settings
        currentLanguage = selectedLanguage
        currentTopics = selectedTopics
        
        // Configure image cache
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Listen for article language changes
        NotificationCenter.default.publisher(for: .articleLanguageChanged)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    print("📱 Article language changed, refreshing...")
                    self?.checkForLanguageChangeAndRefresh()
                }
            }
            .store(in: &cancellables)
        
        // Listen for topic changes
        NotificationCenter.default.publisher(for: .topicsChanged)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    print("📝 Topics changed, refreshing...")
                    self?.checkForTopicsChangeAndRefresh()
                }
            }
            .store(in: &cancellables)
    }
    
    private var selectedLanguage: String {
        UserDefaults.standard.string(forKey: "selectedArticleLanguage") ?? AppLanguage.english.displayName
    }
    
    private var selectedTopics: [String] {
        UserDefaults.standard.array(forKey: "selectedTopics") as? [String] ?? ["All Topics"]
    }
    
    private var languageCode: String {
        // Find the AppLanguage case that matches the selected display name
        if let appLanguage = AppLanguage.allCases.first(where: { $0.displayName == selectedLanguage }) {
            let code = appLanguage.rawValue
            // Use fallback for problematic languages
            if problematicLanguages.contains(code) {
                print("⚠️ Language \(code) is problematic, falling back to English")
                return "en"
            }
            return code
        }
        return "en" // Default to English
    }
    
    func fetchRandomArticles(count: Int = 10) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        hasError = false
        
        let publishers = (0..<count).map { _ in
            fetchSingleRandomArticle()
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleFetchError(error)
                    }
                },
                receiveValue: { [weak self] articles in
                    if !articles.isEmpty {
                        self?.articles.append(contentsOf: articles)
                        self?.hasError = false
                        self?.errorMessage = nil
                        
                        // Start preloading next articles
                        self?.preloadArticlesInBackground()
                    } else {
                        self?.handleEmptyResult()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchSingleRandomArticle() -> AnyPublisher<WikipediaArticle, Error> {
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/random/summary"
        
        guard let url = URL(string: urlString) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RandomArticleResponse.self, decoder: JSONDecoder())
            .map { response in
                WikipediaArticle(
                    title: response.title,
                    extract: response.extract,
                    pageId: response.pageId,
                    imageURL: response.thumbnail?.source,
                    fullURL: response.contentURLs.desktop.page
                )
            }
            .catch { [weak self] error -> AnyPublisher<WikipediaArticle, Error> in
                print("⚠️ Failed to fetch article for \(self?.languageCode ?? "unknown"): \(error)")
                // Try fallback to English if current language failed
                return self?.fetchSingleRandomArticleWithFallback() ?? Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
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
        
        isLoading = true
        errorMessage = nil
        hasError = false
        
        if selectedTopics.contains("All Topics") || selectedTopics.isEmpty {
            fetchRandomArticles(count: count)
            return
        }
        
        let publishers = selectedTopics.prefix(3).map { topic in
            fetchArticlesForTopic(topic: topic, count: max(1, count / selectedTopics.count))
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleFetchError(error)
                    }
                },
                receiveValue: { [weak self] articleArrays in
                    let flattenedArticles = articleArrays.flatMap { $0 }
                    if !flattenedArticles.isEmpty {
                        self?.articles.append(contentsOf: flattenedArticles.shuffled())
                        self?.hasError = false
                        self?.errorMessage = nil
                        
                        // Start preloading next articles
                        self?.preloadArticlesInBackground()
                    } else {
                        self?.handleEmptyResult()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchArticlesForTopic(topic: String, count: Int) -> AnyPublisher<[WikipediaArticle], Error> {
        if topic == "All Topics" {
            let publishers = (0..<count).map { _ in
                fetchSingleRandomArticle()
            }
            
            return Publishers.MergeMany(publishers)
                .collect()
                .eraseToAnyPublisher()
        } else {
            return fetchTopicBasedArticles(topic: topic, count: count)
        }
    }
    
    private func fetchTopicBasedArticles(topic: String, count: Int) -> AnyPublisher<[WikipediaArticle], Error> {
        let searchTerms = getSearchTermsForTopic(topic)
        let publishers = searchTerms.prefix(count).map { searchTerm in
            searchWikipediaArticle(searchTerm: searchTerm)
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .eraseToAnyPublisher()
    }
    
    private func getSearchTermsForTopic(_ topic: String) -> [String] {
        switch topic {
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
    
    private func searchWikipediaArticle(searchTerm: String) -> AnyPublisher<WikipediaArticle, Error> {
        let searchURL = "https://\(languageCode).wikipedia.org/api/rest_v1/page/title/\(searchTerm)"
        
        guard let url = URL(string: searchURL) else {
            return fetchSingleRandomArticle()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RandomArticleResponse.self, decoder: JSONDecoder())
            .map { response in
                WikipediaArticle(
                    title: response.title,
                    extract: response.extract,
                    pageId: response.pageId,
                    imageURL: response.thumbnail?.source,
                    fullURL: response.contentURLs.desktop.page
                )
            }
            .catch { _ in
                self.fetchSingleRandomArticle()
            }
            .eraseToAnyPublisher()
    }
    
    
    
    private func checkForLanguageChangeAndRefresh() {
        let newLanguage = selectedLanguage
        
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
        print("🔄 Refreshing articles for language: \(selectedLanguage), topics: \(selectedTopics)")
        
        // Cancel any existing requests
        cancellables.removeAll()
        
        // Clear state
        articles.removeAll()
        preloadedArticles.removeAll()
        imageCache.removeAllObjects()
        isLoading = false
        isPreloading = false
        hasError = false
        errorMessage = nil
        
        // Fetch new articles
        fetchTopicBasedArticles()
    }
    
    private func preloadArticlesInBackground() {
        guard !isPreloading && preloadedArticles.count < 10 else { return }
        
        isPreloading = true
        
        Task {
            do {
                let newArticles = try await fetchArticlesInBackground(count: 5)
                await MainActor.run {
                    self.preloadedArticles.append(contentsOf: newArticles)
                    self.isPreloading = false
                }
                
                // Preload images for the fetched articles
                await preloadImages(for: newArticles)
            } catch {
                await MainActor.run {
                    self.isPreloading = false
                }
            }
        }
    }
    
    private func fetchArticlesInBackground(count: Int) async throws -> [WikipediaArticle] {
        var articles: [WikipediaArticle] = []
        
        if selectedTopics.contains("All Topics") || selectedTopics.isEmpty {
            // Fetch random articles
            for _ in 0..<count {
                if let article = try await fetchSingleRandomArticleAsync() {
                    articles.append(article)
                }
            }
        } else {
            // Fetch topic-based articles
            for topic in selectedTopics.prefix(3) {
                let searchTerms = getSearchTermsForTopic(topic)
                for searchTerm in searchTerms.prefix(max(1, count / selectedTopics.count)) {
                    if let article = try await searchWikipediaArticleAsync(searchTerm: searchTerm) {
                        articles.append(article)
                    }
                }
            }
        }
        
        return articles.shuffled()
    }
    
    private func fetchSingleRandomArticleAsync() async throws -> WikipediaArticle? {
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/random/summary"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RandomArticleResponse.self, from: data)
            
            return WikipediaArticle(
                title: response.title,
                extract: response.extract,
                pageId: response.pageId,
                imageURL: response.thumbnail?.source,
                fullURL: response.contentURLs.desktop.page
            )
        } catch {
            // Try fallback to English if current language failed
            return try await fetchSingleRandomArticleWithFallbackAsync()
        }
    }
    
    private func searchWikipediaArticleAsync(searchTerm: String) async throws -> WikipediaArticle? {
        let searchURL = "https://\(languageCode).wikipedia.org/api/rest_v1/page/title/\(searchTerm)"
        
        guard let url = URL(string: searchURL) else {
            return try await fetchSingleRandomArticleAsync()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(RandomArticleResponse.self, from: data)
            
            return WikipediaArticle(
                title: response.title,
                extract: response.extract,
                pageId: response.pageId,
                imageURL: response.thumbnail?.source,
                fullURL: response.contentURLs.desktop.page
            )
        } catch {
            return try await fetchSingleRandomArticleAsync()
        }
    }
    
    private func fetchSingleRandomArticleWithFallbackAsync() async throws -> WikipediaArticle? {
        let fallbackURL = "https://en.wikipedia.org/api/rest_v1/page/random/summary"
        
        guard let url = URL(string: fallbackURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RandomArticleResponse.self, from: data)
        
        return WikipediaArticle(
            title: response.title,
            extract: response.extract,
            pageId: response.pageId,
            imageURL: response.thumbnail?.source,
            fullURL: response.contentURLs.desktop.page
        )
    }
    
    private func preloadImages(for articles: [WikipediaArticle]) async {
        await withTaskGroup(of: Void.self) { group in
            for article in articles {
                if let imageURLString = article.imageURL,
                   let imageURL = URL(string: imageURLString) {
                    group.addTask {
                        await self.preloadSingleImage(from: imageURL, cacheKey: imageURLString)
                    }
                }
            }
        }
    }
    
    private func preloadSingleImage(from url: URL, cacheKey: String) async {
        // Check if image is already cached
        if imageCache.object(forKey: NSString(string: cacheKey)) != nil {
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let image = UIImage(data: data) {
                // Calculate memory cost (rough estimate)
                let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel for RGBA
                imageCache.setObject(image, forKey: NSString(string: cacheKey), cost: cost)
            }
        } catch {
            // Silently fail for image preloading
            print("📸 Failed to preload image: \(url)")
        }
    }
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return imageCache.object(forKey: NSString(string: urlString))
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
            // Add small delay for debouncing
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            // Use the same opensearch API that gives us better results
            let searchBaseURL = "https://\(languageCode).wikipedia.org/w/api.php"
            var components = URLComponents(string: searchBaseURL)!
            components.queryItems = [
                URLQueryItem(name: "action", value: "opensearch"),
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "limit", value: "5"),
                URLQueryItem(name: "namespace", value: "0"),
                URLQueryItem(name: "format", value: "json")
            ]
            
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = requestTimeout
            request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            // Parse opensearch response [query, [titles], [descriptions], [urls]]
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
                  jsonArray.count >= 4,
                  let titles = jsonArray[1] as? [String],
                  let descriptions = jsonArray[2] as? [String],
                  let urls = jsonArray[3] as? [String] else {
                throw URLError(.cannotParseResponse)
            }
            
            var results: [SearchResult] = []
            for i in 0..<min(titles.count, descriptions.count, urls.count) {
                let result = SearchResult(
                    title: titles[i],
                    description: descriptions[i],
                    url: urls[i]
                )
                results.append(result)
            }
            
            searchResults = results
            isSearching = false
            
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
                let fullArticle = try await fetchFullArticleDetails(from: searchResult)
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
    
    func fetchFullArticleDetails(from searchResult: SearchResult) async throws -> WikipediaArticle {
        let encodedTitle = searchResult.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? searchResult.title
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RandomArticleResponse.self, from: data)
        
        return WikipediaArticle(
            title: response.title,
            extract: response.extract.isEmpty ? searchResult.description : response.extract,
            pageId: response.pageId,
            imageURL: response.thumbnail?.source,
            fullURL: response.contentURLs.desktop.page
        )
    }
    
    func clearSearchResults() {
        searchResults = []
        searchTask?.cancel()
    }
    
    private func handleFetchError(_ error: Error) {
        print("🚨 Wikipedia fetch error: \(error)")
        
        // Check if it's a timeout error
        if error.localizedDescription.contains("timed out") || error.localizedDescription.contains("timeout") {
            errorMessage = "Request timed out. Please check your connection."
        } else {
            errorMessage = error.localizedDescription
        }
        
        hasError = true
        
        // Try fallback to English if we're not already using English
        if languageCode != "en" {
            print("🔄 Attempting fallback to English...")
            fallbackToEnglish()
        }
    }
    
    private func handleEmptyResult() {
        errorMessage = "No articles found for this language"
        hasError = true
        
        // Try fallback to English if we're not already using English
        if languageCode != "en" {
            print("🔄 No articles found, attempting fallback to English...")
            fallbackToEnglish()
        }
    }
    
    private func fallbackToEnglish() {
        // Temporarily override language to English
        let originalLanguage = selectedLanguage
        
        // Set English as fallback
        UserDefaults.standard.set(AppLanguage.english.displayName, forKey: "selectedArticleLanguage")
        
        // Fetch articles in English
        isLoading = true
        hasError = false
        errorMessage = nil
        
        fetchRandomArticles(count: 5)
        
        // Restore original language setting after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UserDefaults.standard.set(originalLanguage, forKey: "selectedArticleLanguage")
        }
    }
    
    private func fetchSingleRandomArticleWithFallback() -> AnyPublisher<WikipediaArticle, Error> {
        let fallbackURL = "https://en.wikipedia.org/api/rest_v1/page/random/summary"
        
        guard let url = URL(string: fallbackURL) else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue("WikiShorts/1.0", forHTTPHeaderField: "User-Agent")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: RandomArticleResponse.self, decoder: JSONDecoder())
            .map { response in
                WikipediaArticle(
                    title: response.title,
                    extract: response.extract,
                    pageId: response.pageId,
                    imageURL: response.thumbnail?.source,
                    fullURL: response.contentURLs.desktop.page
                )
            }
            .eraseToAnyPublisher()
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


