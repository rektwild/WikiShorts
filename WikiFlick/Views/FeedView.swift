import SwiftUI

struct FeedView: View {
    @StateObject private var wikipediaService = WikipediaService()
    @State private var currentIndex = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if wikipediaService.articles.isEmpty && wikipediaService.isLoading {
                LoadingView()
            } else if wikipediaService.hasError {
                ErrorStateView(errorMessage: wikipediaService.errorMessage) {
                    refreshFeed()
                }
            } else if wikipediaService.articles.isEmpty && !wikipediaService.isLoading {
                EmptyStateView {
                    refreshFeed()
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(wikipediaService.articles.enumerated()), id: \.element.id) { index, article in
                        ArticleCardView(article: article)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .ignoresSafeArea()
                .onChange(of: currentIndex) { _, newIndex in
                    if newIndex >= wikipediaService.articles.count - 2 {
                        wikipediaService.loadMoreArticles()
                    }
                }
            }
        }
        .onAppear {
            if wikipediaService.articles.isEmpty {
                wikipediaService.fetchTopicBasedArticles()
            }
        }
        .refreshable {
            refreshFeed()
        }
    }
    
    private func refreshFeed() {
        wikipediaService.articles.removeAll()
        currentIndex = 0
        wikipediaService.fetchTopicBasedArticles()
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading articles...")
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

struct EmptyStateView: View {
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.6))
            
            Text("No articles available")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("Check your internet connection and try again")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                onRetry()
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(25)
        }
        .padding()
    }
}

struct ErrorStateView: View {
    let errorMessage: String?
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.8))
            
            Text("Something went wrong")
                .font(.title2)
                .foregroundColor(.white)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                onRetry()
            }
            .font(.title3)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.red)
            .cornerRadius(25)
        }
        .padding()
    }
}

#Preview {
    FeedView()
}