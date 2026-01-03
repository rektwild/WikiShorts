import Foundation
import UIKit

protocol ArticleCacheManagerProtocol {
    func cacheArticle(_ article: WikipediaArticle)
    func getCachedArticle(pageId: Int) -> WikipediaArticle?
    func cacheImage(_ image: UIImage, for urlString: String)
    func getCachedImage(for urlString: String) -> UIImage?
    func preloadImage(from urlString: String) async -> UIImage?
    func clearImageCache()
    func clearArticleCache()
    func cacheMemoryUsage() -> Int64
}

class ArticleCacheManager: ArticleCacheManagerProtocol {
    static let shared = ArticleCacheManager()
    
    // MARK: - Private Properties
    private let imageCache = NSCache<NSString, UIImage>()
    private var articleCache = [Int: WikipediaArticle]()
    private var articleAccessTime = [Int: Date]()
    private let userAgent = "WikiFlick/1.0"
    
    // MARK: - Thread Safety
    private let cacheQueue = DispatchQueue(label: "com.wikishorts.cache", qos: .utility)
    private let imageQueue = DispatchQueue(label: "com.wikishorts.imageCache", qos: .utility)
    
    // MARK: - Cache Configuration
    private let imageCacheLimit = 50
    private let imageCacheCostLimit = 50 * 1024 * 1024 // 50MB
    private let articleCacheLimit = 100
    
    private init() {
        configureImageCache()
        configureArticleCache()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Configuration
    private func configureImageCache() {
        imageCache.countLimit = imageCacheLimit
        imageCache.totalCostLimit = imageCacheCostLimit
        imageCache.name = "WikiFlick.ImageCache"
    }
    
    private func configureArticleCache() {
        // Article cache is now a dictionary, no configuration needed
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    // MARK: - Article Caching
    func cacheArticle(_ article: WikipediaArticle) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.articleCache[article.pageId] = article
            self.articleAccessTime[article.pageId] = Date()
            
            // Implement manual cache limit
            if self.articleCache.count > self.articleCacheLimit {
                // Remove least recently accessed articles (proper LRU)
                let sortedByAccessTime = self.articleAccessTime.sorted { $0.value < $1.value }
                let keysToRemove = sortedByAccessTime.prefix(self.articleCache.count - self.articleCacheLimit).map(\.key)
                for key in keysToRemove {
                    self.articleCache.removeValue(forKey: key)
                    self.articleAccessTime.removeValue(forKey: key)
                }
                LoggingService.shared.logInfo("Article cache cleaned up, removed \(keysToRemove.count) articles using LRU", category: .cache)
            }
        }
    }
    
    func getCachedArticle(pageId: Int) -> WikipediaArticle? {
        return cacheQueue.sync {
            if let article = articleCache[pageId] {
                // Update access time for LRU
                articleAccessTime[pageId] = Date()
                return article
            }
            return nil
        }
    }
    
    // MARK: - Image Caching
    func cacheImage(_ image: UIImage, for urlString: String) {
        imageQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let cost = self.calculateImageMemoryCost(image)
            let key = NSString(string: urlString)
            self.imageCache.setObject(image, forKey: key, cost: cost)
        }
    }
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return imageQueue.sync { [weak self] in
            guard let self = self else { return nil }
            let key = NSString(string: urlString)
            return self.imageCache.object(forKey: key)
        }
    }
    
    func preloadImage(from urlString: String) async -> UIImage? {
        // Check if already cached
        if let cachedImage = getCachedImage(for: urlString) {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            // Cache the image
            cacheImage(image, for: urlString)
            return image
            
        } catch {
            print("📸 Failed to preload image: \(urlString) - \(error)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    func clearImageCache() {
        imageQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAllObjects()
            print("🧹 Image cache cleared")
        }
    }
    
    func clearArticleCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.articleCache.removeAll()
            self?.articleAccessTime.removeAll()
            print("🧹 Article cache cleared")
        }
    }
    
    func cacheMemoryUsage() -> Int64 {
        return imageQueue.sync { [weak self] in
            guard let self = self else { return 0 }
            // This is an approximation as NSCache doesn't provide exact memory usage
            return Int64(self.imageCache.totalCostLimit)
        }
    }
    
    // MARK: - Private Helpers
    private func calculateImageMemoryCost(_ image: UIImage) -> Int {
        // Calculate approximate memory cost (width * height * 4 bytes for RGBA)
        return Int(image.size.width * image.size.height * 4)
    }
    
    private func handleMemoryWarning() {
        print("🚨 Memory warning received - clearing caches")
        
        // Clear half of the image cache
        imageQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAllObjects()
            print("🧹 Image cache cleared due to memory warning")
        }
        
        // Clear half of the article cache
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let currentCount = self.articleCache.count
            let targetCount = currentCount / 2
            let sortedKeys = self.articleCache.keys.sorted()
            let keysToRemove = sortedKeys.prefix(currentCount - targetCount)
            
            for key in keysToRemove {
                self.articleCache.removeValue(forKey: key)
                self.articleAccessTime.removeValue(forKey: key)
            }
            
            print("🧹 Article cache reduced from \(currentCount) to \(self.articleCache.count) articles due to memory warning")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Cache Statistics
extension ArticleCacheManager {
    func getCacheStatistics() -> CacheStatistics {
        return CacheStatistics(
            imageCacheCount: imageCache.countLimit,
            imageCacheCostLimit: imageCache.totalCostLimit,
            articleCacheCount: articleCache.count
        )
    }
}

struct CacheStatistics {
    let imageCacheCount: Int
    let imageCacheCostLimit: Int
    let articleCacheCount: Int
    
    var description: String {
        return """
        Cache Statistics:
        - Image Cache: \(imageCacheCount) items, \(imageCacheCostLimit / (1024 * 1024))MB limit
        - Article Cache: \(articleCacheCount) items
        """
    }
}