import Foundation
import Combine
import UIKit

protocol WikipediaServiceProtocol: ObservableObject {
    var searchResults: [SearchResult] { get }
    var isSearching: Bool { get }
    
    func searchWikipedia(query: String)
    func clearSearchResults()
    func getCachedImage(for urlString: String) -> UIImage?
}

class WikipediaService: ObservableObject, WikipediaServiceProtocol {
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false

    private var searchTask: Task<Void, Never>?
    
    // Dependencies
    private let articleRepository: ArticleRepositoryProtocol
    private let imageLoadingService: ImageLoadingServiceProtocol
    private let searchHistoryManager = SearchHistoryManager.shared
    private let articleLanguageManager = ArticleLanguageManager.shared
    
    init(
        articleRepository: ArticleRepositoryProtocol = ArticleRepository(),
        imageLoadingService: ImageLoadingServiceProtocol = ImageLoadingService.shared
    ) {
        self.articleRepository = articleRepository
        self.imageLoadingService = imageLoadingService
        
        print("🚀 WikipediaService initialized")
    }

    var languageCode: String {
        let code = articleLanguageManager.languageCode
        // Ensure language is supported for Wikipedia API
        if !articleLanguageManager.isLanguageSupported(articleLanguageManager.selectedLanguage) {
            print("⚠️ Language \(code) is not supported, falling back to English")
            return "en"
        }
        return code
    }
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return imageLoadingService.getCachedImage(for: urlString)
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
            // Add debouncing delay - longer for better UX but not too long
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            let results = try await articleRepository.searchArticles(
                query: query,
                languageCode: languageCode
            ).async()
            
            if !Task.isCancelled {
                searchResults = results
                isSearching = false
                
                // Add to search history if we have results
                if !results.isEmpty {
                    searchHistoryManager.addSearchQuery(
                        query,
                        languageCode: languageCode,
                        resultCount: results.count
                    )
                    
                    // Preload images for search results in background
                    preloadSearchResultImages(results)
                }
            }
            
        } catch {
            if !Task.isCancelled {
                searchResults = []
                isSearching = false
            }
        }
    }
    

    
    
    func clearSearchResults() {
        searchResults = []
        searchTask?.cancel()
    }
    
    // MARK: - Private Helper Methods
    

    
    
    
    
    private func preloadSearchResultImages(_ results: [SearchResult]) {
        Task {
            for result in results.prefix(3) { // Preload only first 3 images to avoid excessive network usage
                if let imageURL = result.displayImageURL {
                    _ = await imageLoadingService.preloadImage(from: imageURL)
                }
            }
        }
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


