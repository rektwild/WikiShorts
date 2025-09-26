import Foundation
import Combine

protocol NetworkServiceProtocol {
    func fetchRandomArticle(languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func searchArticle(searchTerm: String, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func searchWikipedia(query: String, languageCode: String) -> AnyPublisher<[SearchResult], NetworkError>
    func fetchCategoryMembers(category: String, languageCode: String, limit: Int) -> AnyPublisher<[SearchResult], NetworkError>
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidLanguageCode
    case noData
    case decodingError(Error)
    case networkError(Error)
    case timeout
    case notFound
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL format"
        case .invalidLanguageCode:
            return "Invalid language code format"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .timeout:
            return "Request timed out"
        case .notFound:
            return "Resource not found"
        case .unknownError(let message):
            return message
        }
    }
}

class NetworkService: NetworkServiceProtocol {
    private let urlSession: URLSession
    private let requestTimeout: TimeInterval = 8.0
    private let userAgent = "WikiFlick/1.0"

    init(urlSession: URLSession? = nil) {
        if let urlSession = urlSession {
            // Use provided session (useful for testing)
            self.urlSession = urlSession
        } else {
            // Use default URLSession configuration
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.urlSession = URLSession(configuration: configuration)
        }
    }
    
    func fetchRandomArticle(languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError> {
        guard let url = SecureURLBuilder.randomArticleURL(languageCode: languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
        let urlString = url.absoluteString
        
        return performRequest(urlString: urlString)
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
            .catch { error -> AnyPublisher<WikipediaArticle, NetworkError> in
                if languageCode != "en" {
                    return self.fetchRandomArticle(languageCode: "en")
                } else {
                    return Fail(error: self.mapError(error))
                        .eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func searchArticle(searchTerm: String, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError> {
        guard isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
        let searchURL = "https://\(languageCode).wikipedia.org/api/rest_v1/page/title/\(searchTerm)"
        
        return performRequest(urlString: searchURL)
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
                self.fetchRandomArticle(languageCode: languageCode)
            }
            .eraseToAnyPublisher()
    }
    
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError> {
        guard isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
        let encodedTitle = searchResult.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? searchResult.title
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)"
        
        return performRequest(urlString: urlString)
            .decode(type: RandomArticleResponse.self, decoder: JSONDecoder())
            .map { response in
                WikipediaArticle(
                    title: response.title,
                    extract: response.extract.isEmpty ? searchResult.description : response.extract,
                    pageId: response.pageId,
                    imageURL: response.thumbnail?.source,
                    fullURL: response.contentURLs.desktop.page
                )
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func searchWikipedia(query: String, languageCode: String) -> AnyPublisher<[SearchResult], NetworkError> {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Just([])
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }
        
        guard SecureURLBuilder.isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(languageCode).wikipedia.org"
        components.path = "/w/api.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrlimit", value: "5"),
            URLQueryItem(name: "gsrnamespace", value: "0"),
            URLQueryItem(name: "prop", value: "extracts|pageimages|info"),
            URLQueryItem(name: "exintro", value: "true"),
            URLQueryItem(name: "explaintext", value: "true"),
            URLQueryItem(name: "exsentences", value: "3"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "300"),
            URLQueryItem(name: "inprop", value: "url")
        ]
        
        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        return urlSession.dataTaskPublisher(for: request)
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.global(qos: .userInitiated))
            .map(\.data)
            .tryMap { data in
                let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
                
                var results: [SearchResult] = []
                if let pages = searchResponse.query?.pages {
                    for (_, page) in pages {
                        let result = SearchResult(
                            title: page.title,
                            description: page.extract ?? "No description available",
                            url: page.fullurl ?? "https://\(languageCode).wikipedia.org/wiki/\(page.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                            thumbnail: page.thumbnail.map { Thumbnail(source: $0.source, width: $0.width ?? 300, height: $0.height ?? 300) },
                            pageId: page.pageid,
                            imageURL: page.thumbnail?.source
                        )
                        results.append(result)
                    }
                }
                
                return results
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }

    func fetchCategoryMembers(category: String, languageCode: String, limit: Int = 10) -> AnyPublisher<[SearchResult], NetworkError> {
        guard SecureURLBuilder.isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(languageCode).wikipedia.org"
        components.path = "/w/api.php"
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "list", value: "categorymembers"),
            URLQueryItem(name: "cmtitle", value: "Category:\(category)"),
            URLQueryItem(name: "cmlimit", value: String(min(limit, 50))),
            URLQueryItem(name: "cmnamespace", value: "0"), // Main namespace only
            URLQueryItem(name: "cmprop", value: "ids|title"),
            URLQueryItem(name: "cmdir", value: "desc") // Most recent first
        ]

        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        return urlSession.dataTaskPublisher(for: request)
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.global(qos: .userInitiated))
            .map(\.data)
            .tryMap { data in
                let categoryResponse = try JSONDecoder().decode(CategoryMembersResponse.self, from: data)

                guard let members = categoryResponse.query?.categorymembers, !members.isEmpty else {
                    return []
                }

                let results = members.compactMap { member -> SearchResult? in
                    return SearchResult(
                        title: member.title,
                        description: "Article from \(category) category",
                        url: "https://\(languageCode).wikipedia.org/wiki/\(member.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")",
                        thumbnail: nil,
                        pageId: member.pageid,
                        imageURL: nil
                    )
                }

                return results
            }
            .mapError { error in
                self.mapError(error)
            }
            .eraseToAnyPublisher()
    }

    private func performRequest(urlString: String) -> AnyPublisher<Data, Error> {
        guard let url = URL(string: urlString) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        return urlSession.dataTaskPublisher(for: request)
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.global(qos: .userInitiated))
            .map(\.data)
            .mapError { error -> Error in
                return error as Error
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Validation
    
    private func isValidLanguageCode(_ languageCode: String) -> Bool {
        return SecureURLBuilder.isValidLanguageCode(languageCode)
    }
    
    private func mapError(_ error: Error) -> NetworkError {
        if error is DecodingError {
            return .decodingError(error)
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError(error)
            case .badURL:
                return .invalidURL
            default:
                return .networkError(error)
            }
        } else if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
            return .notFound
        } else {
            return .unknownError(error.localizedDescription)
        }
    }
}

// MARK: - Search API Response Models

struct SearchResponse: Codable {
    let query: SearchQuery?
}

struct SearchQuery: Codable {
    let pages: [String: SearchPage]?
}

struct SearchPage: Codable {
    let pageid: Int
    let title: String
    let extract: String?
    let thumbnail: SearchThumbnail?
    let fullurl: String?
    
    enum CodingKeys: String, CodingKey {
        case pageid, title, extract, thumbnail, fullurl
    }
}

struct SearchThumbnail: Codable {
    let source: String
    let width: Int?
    let height: Int?
}

// MARK: - Category Members API Response Models

struct CategoryMembersResponse: Codable {
    let query: CategoryQuery?
}

struct CategoryQuery: Codable {
    let categorymembers: [CategoryMember]?
}

struct CategoryMember: Codable {
    let pageid: Int
    let title: String
}