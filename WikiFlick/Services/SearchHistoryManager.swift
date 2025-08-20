import Foundation
import Combine

protocol SearchHistoryManagerProtocol {
    var recentSearches: [SearchHistory] { get }
    var popularSearches: [String] { get }
    
    func addSearchHistory(_ searchHistory: SearchHistory)
    func clearSearchHistory()
    func removeSearchHistory(withId id: UUID)
    func getFilteredHistory(for query: String) -> [SearchHistory]
    func getSearchSuggestions(for query: String) -> [String]
}

class SearchHistoryManager: ObservableObject, SearchHistoryManagerProtocol {
    static let shared = SearchHistoryManager()
    
    @Published var recentSearches: [SearchHistory] = []
    @Published var popularSearches: [String] = [
        "Science", "History", "Technology", "Art", "Music", 
        "Biology", "Physics", "Geography", "Literature", "Philosophy"
    ]
    
    private let maxHistoryItems = 50
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSearchHistory()
        setupAutosave()
    }
    
    func addSearchHistory(_ searchHistory: SearchHistory) {
        // Remove existing entry with same query to avoid duplicates
        recentSearches.removeAll { $0.query.lowercased() == searchHistory.query.lowercased() }
        
        // Add new search at the beginning
        recentSearches.insert(searchHistory, at: 0)
        
        // Limit the number of stored searches
        if recentSearches.count > maxHistoryItems {
            recentSearches = Array(recentSearches.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
        
        print("🔍 Added search history: \(searchHistory.query) (Total: \(recentSearches.count))")
    }
    
    func clearSearchHistory() {
        recentSearches.removeAll()
        saveSearchHistory()
        print("🗑️ Cleared search history")
    }
    
    func removeSearchHistory(withId id: UUID) {
        recentSearches.removeAll { $0.id == id }
        saveSearchHistory()
        print("🗑️ Removed search history item")
    }
    
    func getFilteredHistory(for query: String) -> [SearchHistory] {
        guard !query.isEmpty else { return Array(recentSearches.prefix(10)) }
        
        return recentSearches.filter { searchHistory in
            searchHistory.query.lowercased().contains(query.lowercased())
        }.prefix(10).map { $0 }
    }
    
    func getSearchSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return Array(popularSearches.prefix(5)) }
        
        var suggestions: [String] = []
        
        // Add recent searches that match
        let matchingHistory = recentSearches.filter { searchHistory in
            searchHistory.query.lowercased().hasPrefix(query.lowercased())
        }.prefix(3)
        
        suggestions.append(contentsOf: matchingHistory.map { $0.query })
        
        // Add popular searches that match
        let matchingPopular = popularSearches.filter { popular in
            popular.lowercased().hasPrefix(query.lowercased()) &&
            !suggestions.contains(popular)
        }.prefix(3)
        
        suggestions.append(contentsOf: matchingPopular)
        
        // Add query completions
        if suggestions.count < 5 {
            let completions = generateQueryCompletions(for: query)
            let remainingSlots = 5 - suggestions.count
            suggestions.append(contentsOf: Array(completions.prefix(remainingSlots)))
        }
        
        return Array(suggestions.prefix(5))
    }
    
    // MARK: - Private Methods
    
    private func loadSearchHistory() {
        guard let data = userDefaults.data(forKey: historyKey) else {
            print("📚 No existing search history found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            recentSearches = try decoder.decode([SearchHistory].self, from: data)
            print("📚 Loaded \(recentSearches.count) search history items")
        } catch {
            print("❌ Failed to load search history: \(error)")
            recentSearches = []
        }
    }
    
    private func saveSearchHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recentSearches)
            userDefaults.set(data, forKey: historyKey)
            print("💾 Saved \(recentSearches.count) search history items")
        } catch {
            print("❌ Failed to save search history: \(error)")
        }
    }
    
    private func setupAutosave() {
        // Auto-save when recentSearches changes
        $recentSearches
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSearchHistory()
            }
            .store(in: &cancellables)
    }
    
    private func generateQueryCompletions(for query: String) -> [String] {
        let commonSuffixes = [
            "history", "definition", "facts", "information", "biography",
            "overview", "summary", "explanation", "guide", "theory"
        ]
        
        return commonSuffixes.compactMap { suffix in
            let completion = "\(query) \(suffix)"
            return completion.count <= 50 ? completion : nil
        }
    }
}

// MARK: - Extensions

extension SearchHistoryManager {
    func getRecentQueries(limit: Int = 10) -> [String] {
        return Array(recentSearches.prefix(limit).map { $0.query })
    }
    
    func getTopLanguages() -> [String] {
        let languageCounts = Dictionary(grouping: recentSearches, by: { $0.languageCode })
            .mapValues { $0.count }
        
        return languageCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    func getSearchStats() -> (totalSearches: Int, uniqueQueries: Int, averageResultCount: Double) {
        let totalSearches = recentSearches.count
        let uniqueQueries = Set(recentSearches.map { $0.query }).count
        let averageResults = recentSearches.isEmpty ? 0.0 : 
            Double(recentSearches.map { $0.resultCount }.reduce(0, +)) / Double(totalSearches)
        
        return (totalSearches, uniqueQueries, averageResults)
    }
}