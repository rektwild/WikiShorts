import XCTest
import Combine
@testable import WikiFlick

final class NetworkServiceTests: XCTestCase {
    
    var networkService: NetworkService!
    var mockURLSession: URLSession!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        cancellables = []
        
        // Create a mock URL session configuration for testing
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockURLSession = URLSession(configuration: config)
        
        networkService = NetworkService(urlSession: mockURLSession)
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        mockURLSession = nil
        networkService = nil
        MockURLProtocol.mockData = nil
        MockURLProtocol.mockError = nil
    }
    
    func testFetchRandomArticleSuccess() throws {
        // Mock successful response
        let mockResponse = """
        {
            "title": "Test Article",
            "extract": "This is a test article extract.",
            "pageid": 12345,
            "thumbnail": {
                "source": "https://example.com/test.jpg"
            },
            "content_urls": {
                "desktop": {
                    "page": "https://en.wikipedia.org/wiki/Test_Article"
                }
            }
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.mockData = mockResponse
        
        let expectation = XCTestExpectation(description: "Fetch random article")
        
        networkService.fetchRandomArticle(languageCode: "en")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Expected success, got error: \(error)")
                    }
                },
                receiveValue: { article in
                    XCTAssertEqual(article.title, "Test Article")
                    XCTAssertEqual(article.pageId, 12345)
                    XCTAssertEqual(article.extract, "This is a test article extract.")
                    XCTAssertEqual(article.imageURL, "https://example.com/test.jpg")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchRandomArticleInvalidLanguage() throws {
        let expectation = XCTestExpectation(description: "Invalid language code")
        
        networkService.fetchRandomArticle(languageCode: "invalid")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, NetworkError.invalidLanguageCode)
                        expectation.fulfill()
                    } else {
                        XCTFail("Expected error for invalid language code")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for invalid language code")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSearchWikipediaSuccess() throws {
        // Mock successful search response
        let mockResponse = """
        {
            "query": {
                "pages": {
                    "12345": {
                        "pageid": 12345,
                        "title": "Search Result",
                        "extract": "This is a search result.",
                        "fullurl": "https://en.wikipedia.org/wiki/Search_Result",
                        "thumbnail": {
                            "source": "https://example.com/search.jpg"
                        }
                    }
                }
            }
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.mockData = mockResponse
        
        let expectation = XCTestExpectation(description: "Search Wikipedia")
        
        networkService.searchWikipedia(query: "test query", languageCode: "en")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Expected success, got error: \(error)")
                    }
                },
                receiveValue: { results in
                    XCTAssertFalse(results.isEmpty)
                    XCTAssertEqual(results.first?.title, "Search Result")
                    XCTAssertEqual(results.first?.pageId, 12345)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchWikipediaEmptyQuery() throws {
        let expectation = XCTestExpectation(description: "Empty search query")
        
        networkService.searchWikipedia(query: "", languageCode: "en")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail for empty query")
                    }
                },
                receiveValue: { results in
                    XCTAssertTrue(results.isEmpty)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testNetworkErrorHandling() throws {
        // Mock network error
        MockURLProtocol.mockError = URLError(.notConnectedToInternet)
        
        let expectation = XCTestExpectation(description: "Network error")
        
        networkService.fetchRandomArticle(languageCode: "en")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        if case .networkError = error {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected network error, got: \(error)")
                        }
                    } else {
                        XCTFail("Expected error for network failure")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for network error")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var mockData: Data?
    static var mockError: Error?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        if let error = MockURLProtocol.mockError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let data = MockURLProtocol.mockData {
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {
        // No-op
    }
}