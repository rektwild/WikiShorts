//
//  FavoritesView.swift
//  WikiFlick
//
//  Created by Kilo Code on 04.01.2026.
//

import SwiftUI

struct FavoritesView: View {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var selectedFavorite: WikipediaArticle?
    @StateObject private var languageManager = AppLanguageManager.shared
    
    @Binding var showingSettings: Bool
    @Binding var showingRewardAlert: Bool
    @Binding var showingNoAdAlert: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if favoritesManager.favorites.isEmpty {
                    emptyFavoritesView
                } else {
                    favoritesListView
                }
            }
            .navigationTitle(languageManager.localizedString(key: "favorites"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    WikiHeaderView(showingPaywall: .constant(false))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    WikiTrailingHeaderView(
                        showingSettings: $showingSettings,
                        showingRewardAlert: $showingRewardAlert,
                        showingNoAdAlert: $showingNoAdAlert
                    )
                }
            }
            .sheet(item: $selectedFavorite) { article in
                if #available(iOS 16.0, *) {
                    ArticleCardView(
                        article: article,
                        onNavigateToTop: nil
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                } else {
                    ArticleCardView(
                        article: article,
                        onNavigateToTop: nil
                    )
                }
            }
        }
    }
    
    private var emptyFavoritesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))
            
            Text(languageManager.localizedString(key: "no_favorites"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.8))
            
            Text(languageManager.localizedString(key: "no_favorites_description"))
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var favoritesListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(favoritesManager.favorites.enumerated()), id: \.element.id) { index, article in
                    FavoriteArticleCardView(article: article) {
                        selectedFavorite = article
                    }
                    
                    if index < favoritesManager.favorites.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 8)
        }
        .refreshable {
            // Refresh favorites (reload from storage)
            favoritesManager.objectWillChange.send()
        }
    }
}

struct FavoriteArticleCardView: View {
    let article: WikipediaArticle
    let onTap: () -> Void
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var imageLoaded = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    AsyncImageView(
                        urlString: imageURL,
                        imageLoadingService: ImageLoadingService.shared
                    ) {
                        thumbnailPlaceholder
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    thumbnailPlaceholder
                }
                
                // Title and Extract
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(article.extract)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(3)
                }
                
                Spacer()
                
                // Heart icon (always filled in favorites view)
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

#Preview {
    FavoritesView(
        showingSettings: .constant(false),
        showingRewardAlert: .constant(false),
        showingNoAdAlert: .constant(false)
    )
    .preferredColorScheme(.dark)
}
