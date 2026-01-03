import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedAppLanguage: AppLanguage = .english
    @State private var selectedArticleLanguage: AppLanguage = .english
    @State private var selectedTopics: Set<String> = []
    @State private var notificationPermissionGranted = false
    
    @StateObject private var appLanguageManager = AppLanguageManager.shared
    @StateObject private var articleLanguageManager = ArticleLanguageManager.shared
    
    @Binding var showOnboarding: Bool
    
    private let topics = TopicManager.topicDisplayNames
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if currentStep == 0 {
                    AppLanguageSelectionView(
                        selectedLanguage: $selectedAppLanguage,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 1
                            }
                        }
                    )
                    .navigationTitle(appLanguageManager.localizedString(key: "select_app_language"))
                    .navigationBarTitleDisplayMode(.large)
                } else if currentStep == 1 {
                    NotificationPermissionView(
                        onAllow: {
                            requestNotificationPermission()
                        },
                        onSkip: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        }
                    )
                    .navigationTitle("Stay Updated")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation { currentStep = 0 }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                            }
                        }
                    }
                } else if currentStep == 2 {
                    OnboardingArticleLanguageSelectionView(
                        selectedLanguage: $selectedArticleLanguage,
                        availableLanguages: articleLanguageManager.availableLanguages,
                        onContinue: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 3
                            }
                        }
                    )
                    .navigationTitle(appLanguageManager.localizedString(key: "select_article_language"))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation { currentStep = 1 }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                            }
                        }
                    }
                } else {
                    OnboardingTopicSelectionView(
                        selectedTopics: $selectedTopics,
                        topics: topics,
                        onGetStarted: {
                            completeOnboarding()
                        }
                    )
                    .navigationTitle("Choose Topics")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                withAnimation { currentStep = 2 }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                initializeSelections()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func initializeSelections() {
        // Initialize with current language manager settings
        selectedAppLanguage = appLanguageManager.currentLanguage
        selectedArticleLanguage = articleLanguageManager.selectedLanguage

        // Initialize topics from UserDefaults using TopicManager
        selectedTopics = TopicManager.getSavedTopicsAsDisplayNames()
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            await MainActor.run {
                notificationPermissionGranted = granted
                if granted {
                    NotificationManager.shared.isNotificationEnabled = true
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 2
                }
            }
        }
    }
    
    private func completeOnboarding() {
        // Apply app language selection to AppLanguageManager
        appLanguageManager.currentLanguage = selectedAppLanguage

        // Apply article language selection to ArticleLanguageManager
        articleLanguageManager.selectLanguage(selectedArticleLanguage)

        // Save topics selection using TopicManager
        TopicManager.saveTopics(displayNames: selectedTopics)

        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        showOnboarding = false
    }
}

// MARK: - Color Extensions
extension Color {
    static let primaryBlue = Color(hex: "135bec")
    static let backgroundLight = Color(hex: "f6f6f8")
    static let backgroundDark = Color(hex: "101622")
    static let surfaceDark = Color(hex: "232f48")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
