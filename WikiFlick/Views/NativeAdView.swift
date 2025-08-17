import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let nativeAd: GADNativeAd
    
    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = GADNativeAdView()
        setupAdView(adView)
        return adView
    }
    
    func updateUIView(_ uiView: GADNativeAdView, context: Context) {
        uiView.nativeAd = nativeAd
    }
    
    private func setupAdView(_ adView: GADNativeAdView) {
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
        adLabel.text = "Ad"
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
    let nativeAd: GADNativeAd
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
            GADMediaViewWrapper(mediaContent: nativeAd.mediaContent)
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
        Text(nativeAd.headline ?? "Sponsored Content")
            .font(.system(size: 28, weight: .bold, design: .default))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
    }
    
    private var descriptionView: some View {
        Text(nativeAd.body ?? "This is a sponsored advertisement.")
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
                Text("Ad")
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
            Text(nativeAd.callToAction ?? "Learn More")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
        }
    }
}

struct GADMediaViewWrapper: UIViewRepresentable {
    let mediaContent: GADMediaContent
    
    func makeUIView(context: Context) -> GADMediaView {
        let mediaView = GADMediaView()
        mediaView.mediaContent = mediaContent
        return mediaView
    }
    
    func updateUIView(_ uiView: GADMediaView, context: Context) {
        uiView.mediaContent = mediaContent
    }
}