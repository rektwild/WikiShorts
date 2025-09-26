import SwiftUI
import Combine
import StoreKit

struct ArticleCardView: View {
    let article: WikipediaArticle
    let onNavigateToTop: (() -> Void)?
    @State private var imageLoaded = false
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    @StateObject private var languageManager = AppLanguageManager.shared
    private let imageLoadingService = ImageLoadingService.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background always visible
                backgroundView

                // Scrollable content
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        mainContent(geometry)
                    }
                    .frame(minHeight: geometry.size.height)
                }

            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Track article read for review request purposes
            ReviewRequestManager.shared.incrementArticleReadCount()
        }
    }
    private var backgroundView: some View {
        Color.black.ignoresSafeArea()
    }
    
    private func bottomContent(article: WikipediaArticle) -> some View {
        VStack(spacing: 0) {
            Spacer()
            contentContainer(article: article)
        }
        .background(gradientBackground)
    }
    
    private func mainContent(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            imageArea(geometry, article: article)
            Spacer()
            bottomContent(article: article)
        }
    }
    
    private func imageArea(_ geometry: GeometryProxy, article: WikipediaArticle) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
                .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.55)
                .overlay(imageContent(geometry, article: article))
            
            HStack(spacing: 8) {
                safariButton(article: article)
                shareButton(article: article)
            }
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 120)
    }
    
    private func imageContent(_ geometry: GeometryProxy, article: WikipediaArticle) -> some View {
        VStack {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                asyncImageView(url: url, geometry: geometry)
                    .onAppear {
                        print("🖼️ Loading image for article: \(article.title)")
                        print("   Image URL: \(imageURL)")
                    }
            } else {
                placeholderView(geometry: geometry)
                    .onAppear {
                        print("📷 No image available for article: \(article.title)")
                        print("   ImageURL: \(article.imageURL ?? "nil")")
                    }
            }
        }
    }
    
    private func asyncImageView(url: URL, geometry: GeometryProxy) -> some View {
        AsyncImageView(
            urlString: url.absoluteString,
            imageLoadingService: imageLoadingService
        ) {
            loadingPlaceholderView(geometry: geometry)
        }
        .aspectRatio(contentMode: .fit)
        .frame(width: geometry.size.width - 40)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .progressiveImageLoading(urlString: url.absoluteString)
        .id(url.absoluteString) // Force view recreation when URL changes
    }
    
    private func loadingPlaceholderView(geometry: GeometryProxy) -> some View {
        LoadingShimmerView(cornerRadius: 20)
            .frame(width: geometry.size.width - 40, height: geometry.size.height * 0.4)
            .overlay(
                LoadingIndicatorView()
            )
    }
    
    private func placeholderView(geometry: GeometryProxy) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.2))
            .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.55)
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
    
    private func contentContainer(article: WikipediaArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            contentInner(article: article)
        }
        .background(outerBackground)
        .padding(.horizontal, 8)
        .padding(.bottom, 50)
    }
    
    private func contentInner(article: WikipediaArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titleView(article: article)
            descriptionView(article: article)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(contentBackground)
    }
    
    private var outerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.85))
    }
    
    private func titleView(article: WikipediaArticle) -> some View {
        Text(article.title)
            .font(.system(size: 28, weight: .bold, design: .default))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
    }
    
    private func descriptionView(article: WikipediaArticle) -> some View {
        Text(article.extract)
            .font(.system(size: 16, weight: .regular, design: .default))
            .foregroundColor(.white.opacity(0.95))
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
    }
    
    
    private var contentBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
    
    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black.opacity(0.1), location: 0.2),
                .init(color: .black.opacity(0.3), location: 0.5),
                .init(color: .black.opacity(0.6), location: 0.8),
                .init(color: .black.opacity(0.9), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    private func safariButton(article: WikipediaArticle) -> some View {
        Button(action: {
            if let url = URL(string: article.fullURL) {
                UIApplication.shared.open(url)
            }
        }) {
            Image(systemName: "safari")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private func shareButton(article: WikipediaArticle) -> some View {
        Button(action: { shareArticle(article: article) }) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    private func shareArticle(article: WikipediaArticle) {
        let activityController = UIActivityViewController(
            activityItems: [article.title, article.fullURL],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
}


#Preview {
    ArticleCardView(
        article: WikipediaArticle(
            title: "Sample Wikipedia Article",
            extract: "This is a sample extract from a Wikipedia article that demonstrates how the content will be displayed in the TikTok-style interface. It includes multiple lines of text to show the layout.",
            pageId: 12345,
            imageURL: nil,
            fullURL: "https://en.wikipedia.org/wiki/Sample"
        ),
        onNavigateToTop: nil
    )
}