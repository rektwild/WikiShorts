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
    
    init() {
        NotificationCenter.default.publisher(for: .settingsChanged)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshArticles()
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
            return appLanguage.rawValue
        }
        return "en" // Default to English
    }
    
    func fetchRandomArticles(count: Int = 10) {
        isLoading = true
        errorMessage = nil
        hasError = false
        
        let publishers = (0..<count).map { _ in
            fetchSingleRandomArticle()
        }
        
        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.hasError = true
                        print("Wikipedia API Error: \(error)")
                    }
                },
                receiveValue: { [weak self] articles in
                    self?.articles.append(contentsOf: articles)
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
        
        return URLSession.shared.dataTaskPublisher(for: url)
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
    
    func loadMoreArticles() {
        fetchTopicBasedArticles(count: 5)
    }
    
    func fetchTopicBasedArticles(count: Int = 10) {
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
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        self?.hasError = true
                        print("Wikipedia API Error: \(error)")
                    }
                },
                receiveValue: { [weak self] articleArrays in
                    let flattenedArticles = articleArrays.flatMap { $0 }
                    self?.articles.append(contentsOf: flattenedArticles.shuffled())
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
        
        return URLSession.shared.dataTaskPublisher(for: url)
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
    
    
    
    private func refreshArticles() {
        articles.removeAll()
        fetchTopicBasedArticles()
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
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
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
        
        let (data, _) = try await URLSession.shared.data(from: url)
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


