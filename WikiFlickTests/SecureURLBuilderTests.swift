import XCTest
@testable import WikiFlick

final class SecureURLBuilderTests: XCTestCase {
    
    func testValidLanguageCodes() throws {
        // Test valid language codes
        XCTAssertTrue(SecureURLBuilder.isValidLanguageCode("en"))
        XCTAssertTrue(SecureURLBuilder.isValidLanguageCode("fr"))
        XCTAssertTrue(SecureURLBuilder.isValidLanguageCode("de"))
        XCTAssertTrue(SecureURLBuilder.isValidLanguageCode("zh"))
        XCTAssertTrue(SecureURLBuilder.isValidLanguageCode("es"))
    }
    
    func testInvalidLanguageCodes() throws {
        // Test invalid language codes
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode(""))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("a"))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("abcd"))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("EN"))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("123"))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("e!"))
        XCTAssertFalse(SecureURLBuilder.isValidLanguageCode("xx")) // Not in supported list
    }
    
    func testRandomArticleURL() throws {
        // Test valid random article URL generation
        let url = SecureURLBuilder.randomArticleURL(languageCode: "en")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "en.wikipedia.org")
        XCTAssertEqual(url?.path, "/api/rest_v1/page/random/summary")
        
        // Test invalid language code returns nil
        let invalidURL = SecureURLBuilder.randomArticleURL(languageCode: "invalid")
        XCTAssertNil(invalidURL)
    }
    
    func testSearchURL() throws {
        // Test valid search URL generation
        let url = SecureURLBuilder.searchURL(languageCode: "en", query: "test query", limit: 10)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "en.wikipedia.org")
        XCTAssertEqual(url?.path, "/api/rest_v1/page/search")
        
        // Test URL components
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        XCTAssertNotNil(queryItems)
        
        let queryItem = queryItems?.first { $0.name == "q" }
        XCTAssertEqual(queryItem?.value, "test query")
        
        let limitItem = queryItems?.first { $0.name == "limit" }
        XCTAssertEqual(limitItem?.value, "10")
    }
    
    func testSearchURLWithInvalidInput() throws {
        // Test empty query returns nil
        let emptyQueryURL = SecureURLBuilder.searchURL(languageCode: "en", query: "", limit: 10)
        XCTAssertNil(emptyQueryURL)
        
        // Test whitespace-only query returns nil
        let whitespaceQueryURL = SecureURLBuilder.searchURL(languageCode: "en", query: "   ", limit: 10)
        XCTAssertNil(whitespaceQueryURL)
        
        // Test invalid limit returns nil
        let invalidLimitURL = SecureURLBuilder.searchURL(languageCode: "en", query: "test", limit: 0)
        XCTAssertNil(invalidLimitURL)
        
        let tooHighLimitURL = SecureURLBuilder.searchURL(languageCode: "en", query: "test", limit: 100)
        XCTAssertNil(tooHighLimitURL)
    }
    
    func testTopicsURL() throws {
        // Test valid topics URL generation
        let url = SecureURLBuilder.topicsURL(languageCode: "en")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "en.wikipedia.org")
        XCTAssertEqual(url?.path, "/api/rest_v1/feed/featured")
        
        // Should have year, month, day query parameters
        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        XCTAssertNotNil(queryItems)
        
        let yearItem = queryItems?.first { $0.name == "year" }
        let monthItem = queryItems?.first { $0.name == "month" }
        let dayItem = queryItems?.first { $0.name == "day" }
        
        XCTAssertNotNil(yearItem)
        XCTAssertNotNil(monthItem)
        XCTAssertNotNil(dayItem)
        
        // Check format
        XCTAssertEqual(yearItem?.value?.count, 4) // YYYY format
        XCTAssertEqual(monthItem?.value?.count, 2) // MM format
        XCTAssertEqual(dayItem?.value?.count, 2) // DD format
    }
}