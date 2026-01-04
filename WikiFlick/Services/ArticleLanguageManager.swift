import Foundation
import Combine

extension Notification.Name {
    static let articleLanguageChanged = Notification.Name("articleLanguageChanged")
}

class ArticleLanguageManager: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            if oldValue != selectedLanguage {
                saveSelectedLanguage()
                notifyLanguageChange()
            }
        }
    }
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    static let shared = ArticleLanguageManager()
    
    private let userDefaultsKey = "selectedArticleLanguageCode"
    
    // Get all languages that work with Wikipedia API
    var availableLanguages: [AppLanguage] {
        return AppLanguage.workingLanguages.sorted { $0.displayName < $1.displayName }
    }
    
    // Get languages filtered by search text
    func filteredLanguages(searchText: String) -> [AppLanguage] {
        if searchText.isEmpty {
            return availableLanguages
        }
        
        return availableLanguages.filter { language in
            language.displayName.localizedCaseInsensitiveContains(searchText) ||
            language.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private init() {
        // Load saved language or default to English
        if let savedLanguageCode = UserDefaults.standard.string(forKey: userDefaultsKey),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            self.selectedLanguage = savedLanguage
        } else if let savedDisplayName = UserDefaults.standard.string(forKey: "selectedArticleLanguage"),
                  let languageFromDisplayName = AppLanguage.languageFromDisplayName(savedDisplayName) {
            // Handle migration from old string-based system
            self.selectedLanguage = languageFromDisplayName
            // Save in new format
            UserDefaults.standard.set(languageFromDisplayName.rawValue, forKey: userDefaultsKey)
            UserDefaults.standard.removeObject(forKey: "selectedArticleLanguage")
        } else {
            self.selectedLanguage = .english
        }
        
        // Ensure selected language is supported
        if !isLanguageSupported(selectedLanguage) {
            selectedLanguage = .english
        }
    }
    
    // MARK: - Public Methods
    
    func selectLanguage(_ language: AppLanguage) {
        guard isLanguageSupported(language) else {
            errorMessage = "Selected language '\(language.displayName)' is not supported for Wikipedia articles."
            Logger.error("Language selection failed: \(language.displayName) (\(language.rawValue)) is not supported", category: .ui)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Logger.info("Selecting language: \(language.displayName) (\(language.rawValue))", category: .ui)
        
        // Validate language code format
        guard !language.rawValue.isEmpty && language.rawValue.count >= 2 else {
            errorMessage = "Invalid language code format."
            isLoading = false
            return
        }
        
        // Simulate brief loading for better UX and ensure state changes are properly observed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedLanguage = language
            self.isLoading = false
            Logger.info("Language successfully changed to: \(language.displayName) (\(language.rawValue))", category: .ui)
        }
    }
    
    func resetToDefault() {
        selectLanguage(.english)
    }
    
    func isLanguageSupported(_ language: AppLanguage) -> Bool {
        return language.isWorkingWikipedia
    }
    
    var languageCode: String {
        return selectedLanguage.rawValue
    }
    
    var displayName: String {
        return selectedLanguage.displayName
    }
    
    var flag: String {
        return selectedLanguage.flag
    }
    
    // MARK: - Private Methods
    
    private func saveSelectedLanguage() {
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: userDefaultsKey)
    }
    
    private func notifyLanguageChange() {
        NotificationCenter.default.post(name: .articleLanguageChanged, object: self)
    }
    
    // MARK: - Debug Methods
    
    func printDebugInfo() {
        Logger.debug("ArticleLanguageManager Debug Info:", category: .ui)
        Logger.debug("   Selected Language: \(selectedLanguage.displayName) (\(selectedLanguage.rawValue))", category: .ui)
        Logger.debug("   Available Languages: \(availableLanguages.count)", category: .ui)
        Logger.debug("   Is Supported: \(isLanguageSupported(selectedLanguage))", category: .ui)
    }
}