import Foundation
import Combine

protocol NetworkServiceProtocol {
    func fetchRandomArticle(languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func searchArticle(searchTerm: String, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func fetchArticleDetails(from searchResult: SearchResult, languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError>
    func searchWikipedia(query: String, languageCode: String) -> AnyPublisher<[SearchResult], NetworkError>
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
    
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    func fetchRandomArticle(languageCode: String) -> AnyPublisher<WikipediaArticle, NetworkError> {
        guard isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/random/summary"
        
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
        
        guard isValidLanguageCode(languageCode) else {
            return Fail(error: NetworkError.invalidLanguageCode)
                .eraseToAnyPublisher()
        }
        
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
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        return urlSession.dataTaskPublisher(for: request)
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.main)
            .map(\.data)
            .tryMap { data in
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
                      jsonArray.count >= 4,
                      let titles = jsonArray[1] as? [String],
                      let descriptions = jsonArray[2] as? [String],
                      let urls = jsonArray[3] as? [String] else {
                    throw NetworkError.decodingError(URLError(.cannotParseResponse))
                }
                
                var results: [SearchResult] = []
                for i in 0..<min(titles.count, descriptions.count, urls.count) {
                    let result = SearchResult(
                        title: titles[i],
                        description: descriptions[i],
                        url: urls[i],
                        thumbnail: nil
                    )
                    results.append(result)
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
            .timeout(.seconds(Int(requestTimeout)), scheduler: DispatchQueue.main)
            .map(\.data)
            .mapError { error -> Error in
                return error as Error
            }
            .eraseToAnyPublisher()
    }
    
    private func isValidLanguageCode(_ code: String) -> Bool {
        return !code.isEmpty && code.count >= 2 && code.allSatisfy { $0.isLetter || $0 == "-" }
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