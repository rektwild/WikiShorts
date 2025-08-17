import SwiftUI

struct ArticleCardView: View {
    let article: WikipediaArticle
    @State private var imageLoaded = false
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    @State private var showingSettings = false
    @State private var showingPaywall = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    backgroundView
                    mainContent(geometry)
                    topOverlayView
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
    }
    
    private var backgroundView: some View {
        Color.black.ignoresSafeArea()
    }
    
    private var bottomContent: some View {
        VStack(spacing: 0) {
            Spacer()
            contentContainer
        }
        .background(gradientBackground)
    }
    
    private func mainContent(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            imageArea(geometry)
            Spacer()
            bottomContent
        }
    }
    
    private func imageArea(_ geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
                .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.55)
                .overlay(imageContent(geometry))
            
            HStack(spacing: 8) {
                safariButton
                shareButton
            }
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 120)
    }
    
    private func imageContent(_ geometry: GeometryProxy) -> some View {
        VStack {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                asyncImageView(url: url, geometry: geometry)
            } else {
                placeholderView(geometry: geometry)
            }
        }
    }
    
    private func asyncImageView(url: URL, geometry: GeometryProxy) -> some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width - 10, height: geometry.size.height * 0.55)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scaleEffect(imageScale)
                .opacity(imageOpacity)
                .onAppear {
                    imageLoaded = true
                    withAnimation(.easeOut(duration: 0.8)) {
                        imageScale = 1.0
                        imageOpacity = 1.0
                    }
                }
        } placeholder: {
            placeholderView(geometry: geometry)
        }
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
    
    private var contentContainer: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentInner
        }
        .background(outerBackground)
        .padding(.horizontal, 8)
        .padding(.bottom, 50)
    }
    
    private var contentInner: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleView
            descriptionView
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(contentBackground)
    }
    
    private var outerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.85))
    }
    
    private var titleView: some View {
        Text(article.title)
            .font(.system(size: 28, weight: .bold, design: .default))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
    }
    
    private var descriptionView: some View {
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
    
    private var topOverlayView: some View {
        VStack {
            HStack(spacing: 8) {
                wLogoButton
                removeAdsButton
                Spacer()
                settingsButton
            }
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    private var wLogoButton: some View {
        Button(action: {}) {
            Text("WikiShorts")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var removeAdsButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack(spacing: 6) {
                Text("Remove Ads")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Image(systemName: "nosign")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var topActionButtons: some View {
        HStack(spacing: 8) {
            safariButton
            shareButton
        }
    }
    
    private var safariButton: some View {
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
    
    private var shareButton: some View {
        Button(action: { shareArticle() }) {
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
    
    private var settingsButton: some View {
        Button(action: {
            showingSettings = true
        }) {
            Image(systemName: "gearshape")
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
    
    private func shareArticle() {
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
        )
    )
}