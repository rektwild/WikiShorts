//
//  FavoritesManager.swift
//  WikiFlick
//
//  Created by Kilo Code on 04.01.2026.
//

import Foundation
import SwiftUI

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favorites: [WikipediaArticle] = []
    
    private let userDefaultsKey = "savedFavorites"
    
    private init() {
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// Toggle favorite status of an article
    func toggleFavorite(_ article: WikipediaArticle) {
        if isFavorite(article) {
            removeFavorite(article)
        } else {
            addFavorite(article)
        }
    }
    
    /// Check if an article is in favorites
    func isFavorite(_ article: WikipediaArticle) -> Bool {
        return favorites.contains { $0.pageId == article.pageId }
    }
    
    /// Add an article to favorites
    func addFavorite(_ article: WikipediaArticle) {
        // Check if already exists to avoid duplicates
        guard !isFavorite(article) else { return }
        
        withAnimation {
            favorites.insert(article, at: 0) // Add to beginning
            saveFavorites()
        }
        
        LoggingService.shared.logInfo("Added to favorites: \(article.title)", category: .general)
    }
    
    /// Remove an article from favorites
    func removeFavorite(_ article: WikipediaArticle) {
        withAnimation {
            favorites.removeAll { $0.pageId == article.pageId }
            saveFavorites()
        }
        
        LoggingService.shared.logInfo("Removed from favorites: \(article.title)", category: .general)
    }
    
    /// Get all favorite articles
    func getFavorites() -> [WikipediaArticle] {
        return favorites
    }
    
    /// Clear all favorites
    func clearAllFavorites() {
        withAnimation {
            favorites.removeAll()
            saveFavorites()
        }
        
        LoggingService.shared.logInfo("Cleared all favorites", category: .general)
    }
    
    // MARK: - Private Methods
    
    /// Save favorites to UserDefaults
    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(favorites)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            LoggingService.shared.logError("Failed to save favorites: \(error.localizedDescription)", category: .general)
        }
    }
    
    /// Load favorites from UserDefaults
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            favorites = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            favorites = try decoder.decode([WikipediaArticle].self, from: data)
            LoggingService.shared.logInfo("Loaded \(favorites.count) favorites", category: .general)
        } catch {
            LoggingService.shared.logError("Failed to load favorites: \(error.localizedDescription)", category: .general)
            favorites = []
        }
    }
}
