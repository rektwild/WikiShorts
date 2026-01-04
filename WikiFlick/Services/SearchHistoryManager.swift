import Foundation
import Combine

class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    
    @Published var searchHistory: [SearchHistory] = []
    private let maxHistoryCount = 20
    private let userDefaults = UserDefaults.standard
    private let historyKey = "searchHistory"
    
    private init() {
        loadSearchHistory()
    }
    
    func addSearchQuery(_ query: String, languageCode: String, resultCount: Int) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Remove duplicate if exists
        searchHistory.removeAll { $0.query.lowercased() == query.lowercased() && $0.languageCode == languageCode }
        
        // Add new search at the beginning
        let newSearch = SearchHistory(
            query: query,
            languageCode: languageCode,
            resultCount: resultCount
        )
        
        searchHistory.insert(newSearch, at: 0)
        
        // Keep only the most recent searches
        if searchHistory.count > maxHistoryCount {
            searchHistory = Array(searchHistory.prefix(maxHistoryCount))
        }
        
        saveSearchHistory()
    }
    
    func removeSearchHistory(_ search: SearchHistory) {
        searchHistory.removeAll { $0.id == search.id }
        saveSearchHistory()
    }
    
    func clearAllHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    func getRecentSearches(for languageCode: String, limit: Int = 5) -> [SearchHistory] {
        return Array(searchHistory
            .filter { $0.languageCode == languageCode }
            .prefix(limit))
    }
    
    func getPopularSearches(limit: Int = 3) -> [SearchHistory] {
        // Get searches with highest result counts
        return Array(searchHistory
            .sorted { $0.resultCount > $1.resultCount }
            .prefix(limit))
    }
    
    private func loadSearchHistory() {
        guard let data = userDefaults.data(forKey: historyKey) else { return }
        
        do {
            let decodedHistory = try JSONDecoder().decode([SearchHistory].self, from: data)
            
            // Filter out old searches (older than 30 days)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            searchHistory = decodedHistory.filter { $0.timestamp > cutoffDate }
        } catch {
            Logger.error("Failed to decode search history: \(error)", category: .storage)
        }
    }
    
    private func saveSearchHistory() {
        do {
            let encoded = try JSONEncoder().encode(searchHistory)
            userDefaults.set(encoded, forKey: historyKey)
        } catch {
            Logger.error("Failed to encode search history: \(error)", category: .storage)
        }
    }
}