import Foundation
import UIKit

protocol SearchCacheManagerProtocol {
    func cacheSearchResults(_ results: [SearchResult], for query: String, languageCode: String)
    func getCachedSearchResults(for query: String, languageCode: String) -> [SearchResult]?
    func clearSearchCache()
    func getCacheSize() -> String
}

class SearchCacheManager: SearchCacheManagerProtocol {
    static let shared = SearchCacheManager()
    
    private let cache = NSCache<NSString, NSArray>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 100 // Maximum cached queries
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    private var cacheMetadata: [String: CacheMetadata] = [:]
    private let metadataKey = "search_cache_metadata"
    
    private init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("SearchCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Configure NSCache
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Load cached metadata
        loadCacheMetadata()
        
        // Setup memory warning observation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        print("🗄️ SearchCacheManager initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func cacheSearchResults(_ results: [SearchResult], for query: String, languageCode: String) {
        let cacheKey = generateCacheKey(query: query, languageCode: languageCode)
        let cacheData = CachedSearchData(results: results, timestamp: Date())
        
        // Cache in memory
        let resultsArray = NSArray(array: results)
        cache.setObject(resultsArray, forKey: cacheKey as NSString)
        
        // Cache metadata
        cacheMetadata[cacheKey] = CacheMetadata(
            query: query,
            languageCode: languageCode,
            resultCount: results.count,
            timestamp: Date(),
            size: estimateDataSize(results)
        )
        
        // Cache to disk asynchronously
        Task.detached(priority: .background) { [weak self] in
            await self?.cacheToDisk(cacheData, key: cacheKey)
        }
        
        // Clean expired cache
        cleanExpiredCache()
        
        print("💾 Cached \(results.count) search results for '\(query)' (\(languageCode))")
    }
    
    func getCachedSearchResults(for query: String, languageCode: String) -> [SearchResult]? {
        let cacheKey = generateCacheKey(query: query, languageCode: languageCode)
        
        // Check if cache is expired
        if let metadata = cacheMetadata[cacheKey],
           Date().timeIntervalSince(metadata.timestamp) > cacheExpirationInterval {
            removeCachedResults(for: cacheKey)
            return nil
        }
        
        // Try memory cache first
        if let cachedArray = cache.object(forKey: cacheKey as NSString) as? [SearchResult] {
            print("📱 Retrieved \(cachedArray.count) cached search results from memory for '\(query)'")
            return cachedArray
        }
        
        // Try disk cache
        if let cachedData = loadFromDisk(key: cacheKey),
           !cachedData.results.isEmpty {
            // Store back in memory cache
            let resultsArray = NSArray(array: cachedData.results)
            cache.setObject(resultsArray, forKey: cacheKey as NSString)
            
            print("💿 Retrieved \(cachedData.results.count) cached search results from disk for '\(query)'")
            return cachedData.results
        }
        
        return nil
    }
    
    func clearSearchCache() {
        // Clear memory cache
        cache.removeAllObjects()
        
        // Clear disk cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Clear metadata
        cacheMetadata.removeAll()
        saveCacheMetadata()
        
        print("🗑️ Search cache cleared")
    }
    
    func getCacheSize() -> String {
        let totalSize = cacheMetadata.values.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    // MARK: - Private Methods
    
    private func generateCacheKey(query: String, languageCode: String) -> String {
        return "\(languageCode)_\(query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))"
    }
    
    private func cacheToDisk(_ data: CachedSearchData, key: String) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL)
        } catch {
            print("❌ Failed to cache search results to disk: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> CachedSearchData? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedData = try decoder.decode(CachedSearchData.self, from: data)
            
            // Check if expired
            if Date().timeIntervalSince(cachedData.timestamp) > cacheExpirationInterval {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
            
            return cachedData
        } catch {
            print("❌ Failed to load search results from disk: \(error)")
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    private func removeCachedResults(for key: String) {
        // Remove from memory
        cache.removeObject(forKey: key as NSString)
        
        // Remove from disk
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
        
        // Remove metadata
        cacheMetadata.removeValue(forKey: key)
        saveCacheMetadata()
    }
    
    private func cleanExpiredCache() {
        let now = Date()
        var keysToRemove: [String] = []
        
        for (key, metadata) in cacheMetadata {
            if now.timeIntervalSince(metadata.timestamp) > cacheExpirationInterval {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            removeCachedResults(for: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned \(keysToRemove.count) expired cache entries")
        }
    }
    
    private func loadCacheMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cacheMetadata = try decoder.decode([String: CacheMetadata].self, from: data)
            print("📋 Loaded cache metadata for \(cacheMetadata.count) entries")
        } catch {
            print("❌ Failed to load cache metadata: \(error)")
            cacheMetadata = [:]
        }
    }
    
    private func saveCacheMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cacheMetadata)
            UserDefaults.standard.set(data, forKey: metadataKey)
        } catch {
            print("❌ Failed to save cache metadata: \(error)")
        }
    }
    
    private func estimateDataSize(_ results: [SearchResult]) -> Int {
        // Rough estimate of data size in bytes
        return results.reduce(0) { total, result in
            let titleSize = result.title.utf8.count
            let descriptionSize = result.description.utf8.count
            let urlSize = result.url.utf8.count
            let thumbnailSize = result.thumbnail?.source.utf8.count ?? 0
            return total + titleSize + descriptionSize + urlSize + thumbnailSize + 100 // base overhead
        }
    }
    
    @objc private func handleMemoryWarning() {
        cache.removeAllObjects()
        print("⚠️ Memory warning: Cleared search cache from memory")
    }
}

// MARK: - Supporting Types

private struct CachedSearchData: Codable {
    let results: [SearchResult]
    let timestamp: Date
}

private struct CacheMetadata: Codable {
    let query: String
    let languageCode: String
    let resultCount: Int
    let timestamp: Date
    let size: Int
}

// MARK: - Extensions

extension SearchCacheManager {
    func getCacheStatistics() -> (entries: Int, totalSize: String, oldestEntry: Date?, newestEntry: Date?) {
        let entries = cacheMetadata.count
        let totalSize = getCacheSize()
        let timestamps = cacheMetadata.values.map { $0.timestamp }
        let oldestEntry = timestamps.min()
        let newestEntry = timestamps.max()
        
        return (entries, totalSize, oldestEntry, newestEntry)
    }
    
    func getCachedQueries(limit: Int = 10) -> [String] {
        return Array(cacheMetadata.values
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0.query })
    }
}