import SwiftUI

struct ArticleCardView: View {
    let article: WikipediaArticle
    let onNavigateToTop: (() -> Void)?
    @State private var imageLoaded = false
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var showingRewardAlert = false
    @State private var showingNoAdAlert = false
    @StateObject private var storeManager = StoreManager()
    @StateObject private var wikipediaService = WikipediaService()
    @State private var isSearchActive = false
    @State private var searchText = ""
    @State private var selectedSearchArticle: WikipediaArticle?
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    backgroundView
                    mainContent(geometry)
                    topOverlayView
                    if isSearchActive && !wikipediaService.searchResults.isEmpty {
                        searchResultsOverlay
                    }
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
        .alert("Ödüllü Reklam", isPresented: $showingRewardAlert) {
            Button("İzle") {
                if AdMobManager.shared.isRewardedAdLoaded {
                    AdMobManager.shared.showRewardedAd()
                } else {
                    showingNoAdAlert = true
                }
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("10 dakika reklamsız kullanım hakkı için reklam izlemek ister misiniz?")
        }
        .alert("Reklam Bulunamadı", isPresented: $showingNoAdAlert) {
            Button("Tamam") { }
        } message: {
            Text("Şuanda gösterilecek reklam yok, daha sonra tekrar deneyin.")
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
    }
    
    private func refreshPage() {
        // WikipediaService'i refresh et
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
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
        let displayArticle = selectedSearchArticle ?? article
        return VStack(spacing: 0) {
            imageArea(geometry, article: displayArticle)
            Spacer()
            bottomContent(article: displayArticle)
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
    
    private var topOverlayView: some View {
        VStack {
            HStack(spacing: 8) {
                profileImageView
                
                if isSearchActive {
                    searchBarView
                } else {
                    if selectedSearchArticle != nil {
                        backToFeedButton
                    } else if !storeManager.isPurchased("wiki_m") {
                        removeAdsButton
                    }
                    Spacer()
                    if !storeManager.isPurchased("wiki_m") {
                        searchButton
                        giftButton
                    } else {
                        searchButton
                    }
                }
                settingsButton
            }
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    private var profileImageView: some View {
        Button(action: {
            if selectedSearchArticle != nil {
                selectedSearchArticle = nil
            } else {
                refreshPage()
            }
        }) {
            Image("WikiShorts-pre")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    private var backToFeedButton: some View {
        Button(action: {
            selectedSearchArticle = nil
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Back to Feed")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
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
    
    private var searchButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSearchActive = true
            }
        }) {
            Image(systemName: "magnifyingglass")
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
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
                
                TextField("Search Wikipedia...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .accentColor(.white)
                    .onChange(of: searchText) { _, newValue in
                        wikipediaService.searchWikipedia(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        wikipediaService.clearSearchResults()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSearchActive = false
                    searchText = ""
                    wikipediaService.clearSearchResults()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            
            Spacer()
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
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
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
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
    
    private var giftButton: some View {
        Button(action: {
            if AdMobManager.shared.isRewardedAdLoaded {
                showingRewardAlert = true
            } else {
                showingNoAdAlert = true
            }
        }) {
            Image(systemName: "gift")
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
    
    private var searchResultsOverlay: some View {
        VStack(spacing: 0) {
            // Top spacing to position results below search bar
            Rectangle()
                .fill(Color.clear)
                .frame(height: 140)
            
            VStack(spacing: 0) {
                ForEach(wikipediaService.searchResults.prefix(5)) { result in
                    Button(action: {
                        Task {
                            do {
                                let fullArticle = try await wikipediaService.fetchFullArticleDetails(from: result)
                                await MainActor.run {
                                    selectedSearchArticle = fullArticle
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isSearchActive = false
                                        searchText = ""
                                        wikipediaService.clearSearchResults()
                                    }
                                }
                            } catch {
                                // Fallback to basic article if full details fail
                                await MainActor.run {
                                    selectedSearchArticle = result.wikipediaArticle
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isSearchActive = false
                                        searchText = ""
                                        wikipediaService.clearSearchResults()
                                    }
                                }
                            }
                        }
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                
                                Text(result.description.isEmpty ? "No description available" : result.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Rectangle()
                                .fill(Color.black.opacity(0.8))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if result.id != wikipediaService.searchResults.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            
            Spacer()
        }
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
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