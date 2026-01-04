import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedAppLanguage: AppLanguage = .english
    @State private var selectedArticleLanguage: AppLanguage = .english
    @State private var notificationPermissionGranted = false
    
    @StateObject private var appLanguageManager = AppLanguageManager.shared
    @StateObject private var articleLanguageManager = ArticleLanguageManager.shared
    
    @Binding var showOnboarding: Bool
    
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
                            .navigationTitle(appLanguageManager.localizedString(key: "stay_updated"))
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
                                            Text(appLanguageManager.localizedString(key: "back"))
                                        }
                                    }
                                }
                            }
                        } else if currentStep == 2 {
                            OnboardingArticleLanguageSelectionView(
                                selectedLanguage: $selectedArticleLanguage,
                                availableLanguages: articleLanguageManager.availableLanguages,
                                onContinue: {
                                    completeOnboarding()
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
                                            Text(appLanguageManager.localizedString(key: "back"))
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
        .onChange(of: selectedAppLanguage) { newLanguage in
            // Immediately apply the selected language so onboarding screens update
            appLanguageManager.currentLanguage = newLanguage
        }
    }
    
    private func initializeSelections() {
        // Initialize with current language manager settings
        selectedAppLanguage = appLanguageManager.currentLanguage
        selectedArticleLanguage = articleLanguageManager.selectedLanguage
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

        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        showOnboarding = false
    }
}



#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
