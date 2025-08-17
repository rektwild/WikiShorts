import Foundation
import Combine

class WikipediaService: ObservableObject {
    @Published var articles: [WikipediaArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasError = false
    
    private var cancellables = Set<AnyCancellable>()
    
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
        UserDefaults.standard.string(forKey: "selectedArticleLanguage") ?? "English"
    }
    
    private var selectedTopics: [String] {
        UserDefaults.standard.array(forKey: "selectedTopics") as? [String] ?? ["All Topics"]
    }
    
    private var languageCode: String {
        switch selectedLanguage {
        case "Turkish": return "tr"
        case "German": return "de"
        case "French": return "fr"
        case "Italian": return "it"
        case "Chinese": return "zh"
        case "Spanish": return "es"
        case "Japanese": return "ja"
        default: return "en"
        }
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


