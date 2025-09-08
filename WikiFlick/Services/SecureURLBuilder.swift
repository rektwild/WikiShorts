import Foundation

/// Secure URL construction service to prevent URL injection attacks
struct SecureURLBuilder {
    
    // MARK: - Wikipedia API URLs
    
    static func randomArticleURL(languageCode: String) -> URL? {
        guard isValidLanguageCode(languageCode) else {
            print("⚠️ Invalid language code: \(languageCode)")
            return nil
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(languageCode).wikipedia.org"
        components.path = "/api/rest_v1/page/random/summary"
        
        return components.url
    }
    
    static func topicsURL(languageCode: String) -> URL? {
        guard isValidLanguageCode(languageCode) else {
            print("⚠️ Invalid language code: \(languageCode)")
            return nil
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(languageCode).wikipedia.org"
        components.path = "/api/rest_v1/feed/featured"
        components.queryItems = [
            URLQueryItem(name: "year", value: getCurrentYear()),
            URLQueryItem(name: "month", value: getCurrentMonth()),
            URLQueryItem(name: "day", value: getCurrentDay())
        ]
        
        return components.url
    }
    
    static func searchURL(languageCode: String, query: String, limit: Int = 10) -> URL? {
        guard isValidLanguageCode(languageCode) else {
            print("⚠️ Invalid language code: \(languageCode)")
            return nil
        }
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Empty search query")
            return nil
        }
        
        guard limit > 0 && limit <= 50 else {
            print("⚠️ Invalid search limit: \(limit)")
            return nil
        }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(languageCode).wikipedia.org"
        components.path = "/api/rest_v1/page/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        return components.url
    }
    
    // MARK: - Validation
    
    static func isValidLanguageCode(_ languageCode: String) -> Bool {
        // Validate language code format (2-3 lowercase letters, optionally with region)
        let languagePattern = "^[a-z]{2,3}(-[a-z]{2})?$"
        let regex = try? NSRegularExpression(pattern: languagePattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: languageCode.utf16.count)
        
        guard let regex = regex,
              regex.firstMatch(in: languageCode, options: [], range: range) != nil else {
            return false
        }
        
        // Additional security: Check against known Wikipedia languages
        let supportedLanguages = [
            "en", "de", "fr", "es", "it", "pt", "ru", "ja", "zh", "ar",
            "hi", "ko", "tr", "pl", "nl", "sv", "no", "da", "fi", "he",
            "th", "vi", "uk", "cs", "hu", "ro", "bg", "hr", "sk", "sl",
            "et", "lv", "lt", "mk", "sq", "eu", "ca", "gl", "cy", "ga",
            "mt", "is", "fo", "kl", "gd", "gv", "br", "kw", "co", "rm",
            "fur", "lad", "an", "ast", "ext", "mwl", "mihr", "nap", "scn",
            "vec", "lmo", "pms", "rgn", "lij", "eml", "frp", "oc", "pcd",
            "wa", "nrm", "vls", "li", "zea", "fy", "stq", "nds", "de-at",
            "de-ch", "bar", "ksh", "pfl", "als", "gsw", "lb", "nl-be"
        ]
        
        return supportedLanguages.contains(languageCode.lowercased())
    }
    
    // MARK: - Date Helpers
    
    private static func getCurrentYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    private static func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter.string(from: Date())
    }
    
    private static func getCurrentDay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: Date())
    }
}

// MARK: - NetworkError Extension

extension NetworkError {
    static var invalidLanguageCode: NetworkError {
        return .invalidURL
    }
    
    static var invalidSearchQuery: NetworkError {
        return .invalidURL
    }
}