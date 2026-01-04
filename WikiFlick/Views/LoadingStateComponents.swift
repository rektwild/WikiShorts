import SwiftUI

// MARK: - Loading State Components

struct LoadingShimmerView: View {
    @State private var isAnimating = false
    
    let cornerRadius: CGFloat
    let height: CGFloat?
    
    init(cornerRadius: CGFloat = 8, height: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.4),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .if(height != nil) { view in
                view.frame(height: height!)
            }
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.3),
                        .init(color: .black, location: 0.7),
                        .init(color: .clear, location: 1)
                    ]),
                    startPoint: isAnimating ? .leading : UnitPoint(x: -0.3, y: 0.5),
                    endPoint: isAnimating ? .trailing : UnitPoint(x: 0.3, y: 0.5)
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonArticleCardView: View {
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 0) {
            // Image skeleton with button placeholders
            ZStack(alignment: .bottomTrailing) {
                LoadingShimmerView(cornerRadius: 20)
                    .frame(
                        width: geometry.size.width - 20,
                        height: geometry.size.height * 0.55
                    )
                
                // Button placeholders (Safari & Share)
                HStack(spacing: 8) {
                    ForEach(0..<2) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .padding(.bottom, 8)
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 120)
            
            Spacer()
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 12) {
                // Title skeleton
                VStack(spacing: 8) {
                    LoadingShimmerView(cornerRadius: 4, height: 28)
                    LoadingShimmerView(cornerRadius: 4, height: 28)
                        .frame(width: geometry.size.width * 0.6)
                }
                
                // Description skeleton
                VStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        LoadingShimmerView(
                            cornerRadius: 4,
                            height: 16
                        )
                        .frame(width: index == 3 ? geometry.size.width * 0.7 : nil)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20) // Updated to 20
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 50)
        }
    }
}

struct LoadingIndicatorView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.8)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.2), .white]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 24, height: 24)
            .rotationEffect(Angle(degrees: rotationAngle))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
    }
}

struct PulsingLoadingView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.3))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 1.2
                    opacity = 0.1
                }
            }
    }
}

// MARK: - Enhanced Loading States for Feed

struct FeedLoadingView: View {
    var body: some View {
        GeometryReader { geometry in
            SkeletonArticleCardView(geometry: geometry)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
    }
}

struct SearchResultsSkeletonView: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    // Image thumbnail skeleton
                    LoadingShimmerView(cornerRadius: 8)
                        .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Title skeleton
                        LoadingShimmerView(cornerRadius: 4, height: 16)
                        LoadingShimmerView(cornerRadius: 4, height: 16)
                            .frame(width: CGFloat.random(in: 120...200))
                        
                        // Description skeleton
                        LoadingShimmerView(cornerRadius: 4, height: 14)
                            .frame(width: CGFloat.random(in: 180...250))
                        LoadingShimmerView(cornerRadius: 4, height: 14)
                            .frame(width: CGFloat.random(in: 100...180))
                    }
                    
                    Spacer()
                    
                    // Chevron skeleton
                    LoadingShimmerView(cornerRadius: 2)
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if index < 4 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
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
    }
}

// MARK: - Enhanced Search Loading States

struct SearchLoadingIndicator: View {
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .scaleEffect(scaleForIndex(index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
            
            Text("Searching...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .onAppear {
            animationPhase = 1
        }
    }
    
    private func scaleForIndex(_ index: Int) -> CGFloat {
        let phase = (animationPhase + Double(index) * 0.2).truncatingRemainder(dividingBy: 1)
        return 0.5 + 0.5 * sin(phase * .pi * 2)
    }
}

struct EmptySearchStateView: View {
    let query: String
    @StateObject private var languageManager = AppLanguageManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No results found")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Try searching for something else")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func skeletonStyle() -> some View {
        self.modifier(SkeletonModifier())
    }
}

struct SkeletonModifier: ViewModifier {
    @State private var showSkeleton = true
    
    func body(content: Content) -> some View {
        content
            .opacity(showSkeleton ? 0 : 1)
            .overlay(
                LoadingShimmerView()
                    .opacity(showSkeleton ? 1 : 0)
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showSkeleton = false
                    }
                }
            }
    }
}