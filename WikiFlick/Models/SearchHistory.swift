import Foundation

struct SearchHistory: Identifiable, Codable {
    let id: UUID
    let query: String
    let languageCode: String
    let resultCount: Int
    let timestamp: Date
    
    init(query: String, languageCode: String, resultCount: Int, timestamp: Date = Date()) {
        self.id = UUID()
        self.query = query
        self.languageCode = languageCode
        self.resultCount = resultCount
        self.timestamp = timestamp
    }
}