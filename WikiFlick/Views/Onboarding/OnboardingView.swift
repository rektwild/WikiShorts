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
                
                VStack(spacing: 0) {

                    // Content
                    ZStack {
                        if currentStep == 0 {
                            AppLanguageSelectionView(
                                selectedLanguage: $selectedAppLanguage,
                                onContinue: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
                                }
                            )
                            .navigationTitle("Stay Updated")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                                            currentStep = 0 
                                        }
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
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentStep = 3
                                    }
                                }
                            )
                            .navigationTitle(appLanguageManager.localizedString(key: "select_article_language"))
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                                            currentStep = 1 
                                        }
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
                            .navigationTitle("What interests you?")
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { 
                                            currentStep = 2 
                                        }
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



#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
