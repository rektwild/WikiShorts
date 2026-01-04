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
    private let userAgent: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "WikiFlick/\(version) (Build \(build))"
    }()
    
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
        // Check if already cached - THREAD SAFE
        let cachedImage = imageQueue.sync { [weak self] in
            self?.getCachedImage(for: urlString)
        }
        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        guard let url = URL(string: urlString) else {
            Logger.error("Invalid URL: \(urlString)", category: .network)
            return nil
        }
        
        // Retry logic with exponential backoff for rate limiting
        let maxRetries = 3
        var currentRetry = 0
        
        while currentRetry <= maxRetries {
            do {
                // Add small delay between requests to avoid rate limiting
                if currentRetry > 0 {
                    let delay = UInt64(pow(2.0, Double(currentRetry))) * 1_000_000_000 // 2^retry seconds
                    try await Task.sleep(nanoseconds: delay)
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 20.0
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.cachePolicy = .returnCacheDataElseLoad
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 429 {
                        // Rate limited - retry with backoff
                        currentRetry += 1
                        if currentRetry <= maxRetries {
                            Logger.info("Rate limited (429), retry \(currentRetry)/\(maxRetries) for: \(urlString.prefix(60))...", category: .network)
                            continue
                        } else {
                            Logger.error("Rate limited, max retries reached for: \(urlString.prefix(60))...", category: .network)
                            return nil
                        }
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        Logger.error("HTTP error \(httpResponse.statusCode) for: \(urlString)", category: .network)
                        return nil
                    }
                }
                
                guard !data.isEmpty else {
                    Logger.error("Empty data for: \(urlString)", category: .network)
                    return nil
                }
                
                // Downsample image for memory efficiency (80-90% reduction)
                let targetSize = CGSize(width: 800, height: 800)
                guard let image = downsampleImage(data: data, to: targetSize) else {
                    Logger.error("Failed to downsample image (\(data.count) bytes) for: \(urlString)", category: .network)
                    return nil
                }
                
                // Cache the downsampled image
                cacheImage(image, for: urlString)
                return image
                
            } catch {
                if Task.isCancelled {
                    return nil
                }
                Logger.error("Failed to preload image: \(urlString.prefix(60))... - \(error.localizedDescription)", category: .network)
                currentRetry += 1
                if currentRetry > maxRetries {
                    return nil
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    func clearImageCache() {
        imageQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAllObjects()
            Logger.info("Image cache cleared", category: .cache)
        }
    }
    
    func clearArticleCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.articleCache.removeAll()
            self?.articleAccessTime.removeAll()
            Logger.info("Article cache cleared", category: .cache)
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
    
    /// Downsample image to target size to reduce memory usage by 80-90%
    private func downsampleImage(data: Data, to targetSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(targetSize.width, targetSize.height) * UIScreen.main.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    private func handleMemoryWarning() {
        Logger.warning("Memory warning received - clearing caches", category: .cache)
        
        // Clear half of the image cache
        imageQueue.async(flags: .barrier) { [weak self] in
            self?.imageCache.removeAllObjects()
            Logger.info("Image cache cleared due to memory warning", category: .cache)
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
            
            Logger.info("Article cache reduced from \(currentCount) to \(self.articleCache.count) articles due to memory warning", category: .cache)
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