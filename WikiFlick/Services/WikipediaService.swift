import Foundation
import Combine

class WikipediaService: ObservableObject {
    @Published var articles: [WikipediaArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasError = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchRandomArticles(count: Int = 10) {
        isLoading = true
        errorMessage = nil
        hasError = false
        
        let urlString = "https://en.wikipedia.org/api/rest_v1/page/random/summary"
        
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
        let urlString = "https://en.wikipedia.org/api/rest_v1/page/random/summary"
        
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
        fetchRandomArticles(count: 5)
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