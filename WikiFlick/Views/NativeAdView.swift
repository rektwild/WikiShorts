import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> GoogleMobileAds.NativeAdView {
        let adView = GoogleMobileAds.NativeAdView()
        setupAdView(adView)
        return adView
    }
    
    func updateUIView(_ uiView: GoogleMobileAds.NativeAdView, context: Context) {
        uiView.nativeAd = nativeAd
    }
    
    private func setupAdView(_ adView: GoogleMobileAds.NativeAdView) {
        adView.backgroundColor = UIColor.black
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true
        
        // Main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(containerView)
        
        // Headline label
        let headlineLabel = UILabel()
        headlineLabel.font = UIFont.boldSystemFont(ofSize: 18)
        headlineLabel.textColor = .white
        headlineLabel.numberOfLines = 2
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel
        
        // Body text label
        let bodyLabel = UILabel()
        bodyLabel.font = UIFont.systemFont(ofSize: 14)
        bodyLabel.textColor = .lightGray
        bodyLabel.numberOfLines = 3
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel
        
        // Call to action button
        let ctaButton = UIButton(type: .system)
        ctaButton.backgroundColor = UIColor.systemBlue
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        ctaButton.layer.cornerRadius = 6
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(ctaButton)
        adView.callToActionView = ctaButton
        
        // Icon image view
        let iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.cornerRadius = 6
        iconImageView.clipsToBounds = true
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(iconImageView)
        adView.iconView = iconImageView
        
        // Ad indicator
        let adLabel = UILabel()
        adLabel.text = AppLanguageManager.shared.localizedString(key: "ad")
        adLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        adLabel.textColor = .systemYellow
        adLabel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        adLabel.textAlignment = .center
        adLabel.layer.cornerRadius = 3
        adLabel.clipsToBounds = true
        adLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(adLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
            containerView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),
            
            // Ad label
            adLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            adLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            adLabel.widthAnchor.constraint(equalToConstant: 24),
            adLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: adLabel.leadingAnchor, constant: -8),
            
            // Body
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // CTA Button
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            ctaButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ctaButton.heightAnchor.constraint(equalToConstant: 32),
            ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            ctaButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}

struct NativeAdCardView: View {
    let nativeAd: NativeAd
    @State private var imageLoaded = false
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    backgroundView
                    mainContent(geometry)
                    topOverlayView
                    adIndicator
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .ignoresSafeArea()
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
                ctaButton
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
            MediaViewWrapper(mediaContent: nativeAd.mediaContent)
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
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
            
            Text(nativeAd.headline ?? "🌟 Featured Content")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            
            Spacer()
        }
    }
    
    private var descriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(nativeAd.body ?? "Discover amazing content tailored just for you! This sponsored content brings you the best recommendations and exciting new discoveries.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
            
            // Enhanced branding section
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text(AppLanguageManager.shared.localizedString(key: "sponsored_recommended"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text(AppLanguageManager.shared.localizedString(key: "premium_pick"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
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
                Spacer()
            }
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    private var profileImageView: some View {
        Button(action: {
            refreshPage()
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
    
    private func refreshPage() {
        // WikipediaService'i refresh et
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
    }
    
    private var adIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Text(AppLanguageManager.shared.localizedString(key: "ad"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                    .cornerRadius(4)
                    .shadow(radius: 2)
            }
            .padding(.top, 120)
            .padding(.trailing, 20)
            Spacer()
        }
    }
    
    private var ctaButton: some View {
        Button(action: {
            // CTA action handled by AdMob
        }) {
            Text(nativeAd.callToAction ?? "Discover Now")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
        }
    }
}

struct FeedAdView: View {
    let nativeAd: NativeAd
    @State private var imageScale: CGFloat = 0.8
    @State private var imageOpacity: Double = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                ZStack {
                    backgroundView
                    mainContent(geometry)
                    topOverlayView
                    adIndicator
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .ignoresSafeArea()
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
            placeholderImageArea(geometry)
            Spacer()
            bottomContent
        }
    }
    
    private func placeholderImageArea(_ geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
                .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.55)
                .overlay(placeholderContent(geometry))
            
            HStack(spacing: 8) {
                ctaButton
            }
            .padding(.bottom, 8)
            .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 120)
    }
    
    private func placeholderContent(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // Gradient background for visual appeal
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.blue.opacity(0.8), location: 0.0),
                    .init(color: Color.purple.opacity(0.6), location: 0.5),
                    .init(color: Color.indigo.opacity(0.8), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated elements
            VStack(spacing: 16) {
                // Rotating icon animation
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                        .scaleEffect(imageScale)
                }
                .rotationEffect(.degrees(imageOpacity * 360))
                
                VStack(spacing: 8) {
                    Text(AppLanguageManager.shared.localizedString(key: "sponsored_content"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(AppLanguageManager.shared.localizedString(key: "discover_amazing_content"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            
            // Floating particles effect
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                    .offset(
                        x: CGFloat.random(in: -100...100),
                        y: CGFloat.random(in: -100...100)
                    )
                    .scaleEffect(imageOpacity)
                    .opacity(imageOpacity * 0.6)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: imageOpacity
                    )
            }
        }
        .frame(width: geometry.size.width - 20, height: geometry.size.height * 0.55)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(imageScale)
        .opacity(imageOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                imageScale = 1.0
                imageOpacity = 1.0
            }
        }
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
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.yellow)
            
            Text(nativeAd.headline ?? "🌟 Featured Content")
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
            
            Spacer()
        }
    }
    
    private var descriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(nativeAd.body ?? "Discover amazing content tailored just for you! This sponsored content brings you the best recommendations and exciting new discoveries.")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
            
            // Enhanced branding section
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text(AppLanguageManager.shared.localizedString(key: "sponsored_recommended"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text(AppLanguageManager.shared.localizedString(key: "premium_pick"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
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
                Spacer()
            }
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    private var profileImageView: some View {
        Button(action: {
            refreshPage()
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
    
    private func refreshPage() {
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFeed"), object: nil)
    }
    
    private var adIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Text(AppLanguageManager.shared.localizedString(key: "ad"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow)
                    .cornerRadius(4)
                    .shadow(radius: 2)
            }
            .padding(.top, 120)
            .padding(.trailing, 20)
            Spacer()
        }
    }
    
    private var ctaButton: some View {
        Button(action: {
            // CTA action handled by AdMob
        }) {
            Text(nativeAd.callToAction ?? "Discover Now")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
        }
    }
}

struct MediaViewWrapper: UIViewRepresentable {
    let mediaContent: MediaContent
    
    func makeUIView(context: Context) -> MediaView {
        let mediaView = MediaView()
        mediaView.mediaContent = mediaContent
        return mediaView
    }
    
    func updateUIView(_ uiView: MediaView, context: Context) {
        uiView.mediaContent = mediaContent
    }
}