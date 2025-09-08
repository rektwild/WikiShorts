import XCTest
@testable import WikiFlick

final class ArticleCacheManagerTests: XCTestCase {
    
    var cacheManager: ArticleCacheManager!
    
    override func setUpWithError() throws {
        cacheManager = ArticleCacheManager.shared
        // Clear caches before each test
        cacheManager.clearArticleCache()
        cacheManager.clearImageCache()
    }
    
    override func tearDownWithError() throws {
        cacheManager.clearArticleCache()
        cacheManager.clearImageCache()
        cacheManager = nil
    }
    
    func testArticleCaching() throws {
        // Create a test article
        let testArticle = WikipediaArticle(
            title: "Test Article",
            extract: "This is a test article for unit testing.",
            pageId: 12345,
            imageURL: "https://example.com/test.jpg",
            fullURL: "https://en.wikipedia.org/wiki/Test_Article"
        )
        
        // Cache the article
        cacheManager.cacheArticle(testArticle)
        
        // Wait a bit for async operation to complete
        let expectation = XCTestExpectation(description: "Article caching")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Retrieve the cached article
        let cachedArticle = cacheManager.getCachedArticle(pageId: 12345)
        
        // Verify the article was cached correctly
        XCTAssertNotNil(cachedArticle)
        XCTAssertEqual(cachedArticle?.title, testArticle.title)
        XCTAssertEqual(cachedArticle?.pageId, testArticle.pageId)
        XCTAssertEqual(cachedArticle?.extract, testArticle.extract)
    }
    
    func testArticleNotFound() throws {
        // Try to retrieve a non-existent article
        let cachedArticle = cacheManager.getCachedArticle(pageId: 99999)
        
        // Should return nil
        XCTAssertNil(cachedArticle)
    }
    
    func testImageCaching() throws {
        // Create a test image
        let testImage = UIImage(systemName: "star.fill")!
        let testURL = "https://example.com/test-image.jpg"
        
        // Cache the image
        cacheManager.cacheImage(testImage, for: testURL)
        
        // Wait a bit for async operation to complete
        let expectation = XCTestExpectation(description: "Image caching")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Retrieve the cached image
        let cachedImage = cacheManager.getCachedImage(for: testURL)
        
        // Verify the image was cached
        XCTAssertNotNil(cachedImage)
        XCTAssertEqual(cachedImage?.size, testImage.size)
    }
    
    func testImageNotFound() throws {
        // Try to retrieve a non-existent image
        let cachedImage = cacheManager.getCachedImage(for: "https://example.com/nonexistent.jpg")
        
        // Should return nil
        XCTAssertNil(cachedImage)
    }
    
    func testCacheClearingIsThreadSafe() throws {
        // Create multiple test articles
        let articles = (1...10).map { index in
            WikipediaArticle(
                title: "Test Article \(index)",
                extract: "Test extract \(index)",
                pageId: index,
                imageURL: nil,
                fullURL: "https://en.wikipedia.org/wiki/Test_\(index)"
            )
        }
        
        // Cache articles from multiple threads
        let cacheExpectation = XCTestExpectation(description: "Concurrent caching")
        cacheExpectation.expectedFulfillmentCount = articles.count
        
        for article in articles {
            DispatchQueue.global().async {
                self.cacheManager.cacheArticle(article)
                cacheExpectation.fulfill()
            }
        }
        
        wait(for: [cacheExpectation], timeout: 2.0)
        
        // Clear cache from another thread
        let clearExpectation = XCTestExpectation(description: "Cache clearing")
        DispatchQueue.global().async {
            self.cacheManager.clearArticleCache()
            clearExpectation.fulfill()
        }
        
        wait(for: [clearExpectation], timeout: 1.0)
        
        // Verify cache is empty (wait a bit for async operations)
        let verifyExpectation = XCTestExpectation(description: "Cache verification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // All articles should be gone
            for index in 1...10 {
                XCTAssertNil(self.cacheManager.getCachedArticle(pageId: index))
            }
            verifyExpectation.fulfill()
        }
        
        wait(for: [verifyExpectation], timeout: 1.0)
    }
    
    func testCacheMemoryUsage() throws {
        // Test that memory usage reporting works
        let memoryUsage = cacheManager.cacheMemoryUsage()
        
        // Should return a non-negative value
        XCTAssertGreaterThanOrEqual(memoryUsage, 0)
    }
}