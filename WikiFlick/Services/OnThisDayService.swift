//
//  OnThisDayService.swift
//  WikiFlick
//
//  Service for fetching and managing "On This Day" events from Wikipedia
//

import Foundation

/// Service responsible for fetching "On This Day" events from Wikipedia API
class OnThisDayService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var events: [OnThisDayEvent] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let cacheManager: OnThisDayCacheManager
    
    // MARK: - Initialization
    
    init(cacheManager: OnThisDayCacheManager = .shared) {
        self.cacheManager = cacheManager
    }
    
    // MARK: - Public Methods
    
    /// Fetches "On This Day" events for the current date
    /// - Parameter language: The Wikipedia language code (default: current app language)
    func fetchOnThisDayEvents(language: String? = nil) async {
        await fetchOnThisDayEvents(for: Date(), language: language)
    }
    
    /// Fetches "On This Day" events for a specific date
    /// - Parameters:
    ///   - date: The date to fetch events for
    ///   - language: The Wikipedia language code (default: current app language)
    func fetchOnThisDayEvents(for date: Date, language: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let lang = language ?? AppLanguageManager.shared.currentLanguage.rawValue
        
        do {
            // First, try to load from cache
            if let cachedData = cacheManager.loadCachedData(for: date, language: lang) {
                await MainActor.run {
                    self.events = cachedData.toOnThisDayResponse().events
                    self.isLoading = false
                }
                return
            }
            
            // If no cache, fetch from API
            let response = try await fetchFromAPI(for: date, language: lang)
            
            // Cache the response
            cacheManager.cacheData(response, for: date, language: lang)
            
            await MainActor.run {
                self.events = response.events
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Refreshes the events by fetching from API (ignoring cache)
    /// - Parameter language: The Wikipedia language code (default: current app language)
    func refreshEvents(language: String? = nil) async {
        await refreshEvents(for: Date(), language: language)
    }
    
    /// Refreshes the events for a specific date by fetching from API (ignoring cache)
    /// - Parameters:
    ///   - date: The date to refresh events for
    ///   - language: The Wikipedia language code (default: current app language)
    func refreshEvents(for date: Date, language: String? = nil) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        let lang = language ?? AppLanguageManager.shared.currentLanguage.rawValue
        
        do {
            let response = try await fetchFromAPI(for: date, language: lang)
            
            // Cache the response
            cacheManager.cacheData(response, for: date, language: lang)
            
            await MainActor.run {
                self.events = response.events
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Clears the cache for a specific date
    /// - Parameters:
    ///   - date: The date to clear cache for
    ///   - language: The Wikipedia language code (default: current app language)
    func clearCache(for date: Date, language: String? = nil) {
        let lang = language ?? AppLanguageManager.shared.currentLanguage.rawValue
        cacheManager.clearCache(for: date, language: lang)
    }
    
    /// Clears all cached "On This Day" data
    func clearAllCache() {
        cacheManager.clearAllCache()
    }
    
    // MARK: - Private Methods
    
    /// Fetches "On This Day" events from Wikipedia API
    /// - Parameters:
    ///   - date: The date to fetch events for
    ///   - language: The Wikipedia language code
    /// - Returns: OnThisDayResponse containing the events
    private func fetchFromAPI(for date: Date, language: String) async throws -> OnThisDayResponse {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Format month and day with leading zeros (required by Wikipedia API)
        let monthString = String(format: "%02d", month)
        let dayString = String(format: "%02d", day)
        
        // Wikipedia API endpoint for "On this day"
        // Format: https://{language}.wikipedia.org/api/rest_v1/feed/onthisday/all/{month}/{day}
        let urlString = "https://\(language).wikipedia.org/api/rest_v1/feed/onthisday/all/\(monthString)/\(dayString)"
        
        guard let url = URL(string: urlString) else {
            throw OnThisDayError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("WikiFlick/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnThisDayError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OnThisDayError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(OnThisDayResponse.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw OnThisDayError.decodingError(error)
        }
    }
}

// MARK: - On This Day Error

enum OnThisDayError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for Wikipedia API"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - On This Day Cache Manager

/// Manages caching of "On This Day" events
class OnThisDayCacheManager {
    
    static let shared = OnThisDayCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesURL.appendingPathComponent("OnThisDayCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Generates a cache file name for a specific date and language
    private func cacheFileName(for date: Date, language: String) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(language)_\(month)_\(day).json"
    }
    
    /// Gets the cache file URL for a specific date and language
    private func cacheFileURL(for date: Date, language: String) -> URL {
        let fileName = cacheFileName(for: date, language: language)
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    /// Caches "On This Day" data
    /// - Parameters:
    ///   - response: The response to cache
    ///   - date: The date of the events
    ///   - language: The language code
    func cacheData(_ response: OnThisDayResponse, for date: Date, language: String) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let dateString = String(format: "%02d-%02d", month, day)
        
        let cachedData = CachedOnThisDayData(
            date: dateString,
            language: language,
            events: response.events.map { $0.toCached() },
            cachedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(cachedData)
            let fileURL = cacheFileURL(for: date, language: language)
            try data.write(to: fileURL)
        } catch {
            print("Failed to cache data: \(error)")
        }
    }
    
    /// Loads cached "On This Day" data
    /// - Parameters:
    ///   - date: The date of the events
    ///   - language: The language code
    /// - Returns: CachedOnThisDayData if available and not expired, nil otherwise
    func loadCachedData(for date: Date, language: String) -> CachedOnThisDayData? {
        let fileURL = cacheFileURL(for: date, language: language)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let cachedData = try decoder.decode(CachedOnThisDayData.self, from: data)
            
            // Check if cache is expired
            guard !cachedData.isExpired else {
                // Remove expired cache
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
            
            return cachedData
        } catch {
            print("Failed to load cached data: \(error)")
            return nil
        }
    }
    
    /// Clears cache for a specific date and language
    /// - Parameters:
    ///   - date: The date to clear cache for
    ///   - language: The language code
    func clearCache(for date: Date, language: String) {
        let fileURL = cacheFileURL(for: date, language: language)
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Clears all cached "On This Day" data
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// Gets the total size of the cache in bytes
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
}
