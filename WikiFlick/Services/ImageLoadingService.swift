import UIKit
import SwiftUI
import Combine

protocol ImageLoadingServiceProtocol {
    func loadImage(from urlString: String) -> AnyPublisher<UIImage?, Never>
    func preloadImage(from urlString: String) async -> UIImage?
    func getCachedImage(for urlString: String) -> UIImage?
}

class ImageLoadingService: ImageLoadingServiceProtocol {
    static let shared = ImageLoadingService()
    
    private let cacheManager: ArticleCacheManagerProtocol
    private let urlSession: URLSession
    private let userAgent = "WikiFlick/1.0"
    
    private init(
        cacheManager: ArticleCacheManagerProtocol = ArticleCacheManager.shared,
        urlSession: URLSession = .shared
    ) {
        self.cacheManager = cacheManager
        self.urlSession = urlSession
    }
    
    func loadImage(from urlString: String) -> AnyPublisher<UIImage?, Never> {
        // Check cache first
        if let cachedImage = cacheManager.getCachedImage(for: urlString) {
            return Just(cachedImage)
                .eraseToAnyPublisher()
        }
        
        // Load from network
        guard let url = URL(string: urlString) else {
            return Just(nil)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        return urlSession.dataTaskPublisher(for: request)
            .map { data, _ in
                guard let image = UIImage(data: data) else {
                    return nil
                }
                // Cache the image
                self.cacheManager.cacheImage(image, for: urlString)
                return image
            }
            .catch { _ in
                Just(nil)
            }
            .eraseToAnyPublisher()
    }
    
    func preloadImage(from urlString: String) async -> UIImage? {
        return await cacheManager.preloadImage(from: urlString)
    }
    
    func getCachedImage(for urlString: String) -> UIImage? {
        return cacheManager.getCachedImage(for: urlString)
    }
}

// MARK: - Async Image View with Progressive Loading
struct AsyncImageView: View {
    let urlString: String?
    let imageLoadingService: ImageLoadingServiceProtocol
    let placeholder: AnyView
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(
        urlString: String?,
        imageLoadingService: ImageLoadingServiceProtocol = ImageLoadingService.shared,
        @ViewBuilder placeholder: () -> some View
    ) {
        self.urlString = urlString
        self.imageLoadingService = imageLoadingService
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if isLoading {
                placeholder
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    )
            } else {
                placeholder
            }
        }
        .task(id: urlString) {
            await loadImage()
        }
    }
    
    @MainActor
    private func loadImage() async {
        guard let urlString = urlString else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        // Check cache first
        if let cachedImage = imageLoadingService.getCachedImage(for: urlString) {
            withAnimation(.easeOut(duration: 0.3)) {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }
        
        // Load from network
        let loadedImage = await imageLoadingService.preloadImage(from: urlString)
        
        if !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.3)) {
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }
}

// MARK: - Progressive Loading View Modifier
struct ProgressiveImageLoading: ViewModifier {
    let urlString: String?
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(imageScale)
            .opacity(imageOpacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    imageScale = 1.0
                    imageOpacity = 1.0
                }
            }
    }
}

extension View {
    func progressiveImageLoading(urlString: String?) -> some View {
        self.modifier(ProgressiveImageLoading(urlString: urlString))
    }
}