import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var selectedAppLanguage = "English"
    @State private var selectedArticleLanguage = "English"
    @State private var selectedTopics: Set<String> = ["All Topics"]
    @State private var notificationPermissionGranted = false
    
    @Binding var showOnboarding: Bool
    
    private let appLanguages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
    private let articleLanguages = AppLanguage.workingLanguages.prefix(8).map { $0.displayName }
    private let topics = [
        "All Topics",
        "General Reference", 
        "Culture and the Arts",
        "Geography and Places",
        "Health and Fitness",
        "History and Events",
        "Human Activities",
        "Mathematics and Logic",
        "Natural and Physical Sciences",
        "People and Self",
        "Philosophy and Thinking",
        "Religion and Belief Systems",
        "Society and Social Sciences",
        "Technology and Applied Sciences"
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if currentStep == 0 {
                AppLanguageSelectionScreen()
            } else if currentStep == 1 {
                NotificationPermissionScreen()
            } else {
                ArticlePreferencesScreen()
            }
        }
    }
    
    private func AppLanguageSelectionScreen() -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Welcome to WikiShorts")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Choose your app language")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                ForEach(appLanguages, id: \.self) { language in
                    Button(action: {
                        selectedAppLanguage = language
                    }) {
                        HStack {
                            Text(language)
                                .font(.system(size: 18, weight: .medium))
                            Spacer()
                            if language == selectedAppLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(language == selectedAppLanguage ? Color.blue : Color.white.opacity(0.2), lineWidth: 2)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 1
                }
            }) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
    
    private func ArticlePreferencesScreen() -> some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Image("topic-select")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 160)
            }
            
            VStack(spacing: 24) {
                // Article Language Section
                VStack(alignment: .center, spacing: 12) {
                    Text("Article Language")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(articleLanguages, id: \.self) { language in
                                Button(action: {
                                    selectedArticleLanguage = language
                                }) {
                                    Text(language)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(language == selectedArticleLanguage ? .black : .white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(language == selectedArticleLanguage ? Color.white : Color.white.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.trailing, 40)
                    }
                }
                
                // Topics Section
                VStack(alignment: .center, spacing: 12) {
                    Text("Interested Topics")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    let chunkedTopics = topics.chunked(into: 3)
                    
                    VStack(spacing: 12) {
                        ForEach(0..<chunkedTopics.count, id: \.self) { rowIndex in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(chunkedTopics[rowIndex], id: \.self) { topic in
                                        Button(action: {
                                            toggleTopic(topic)
                                        }) {
                                            Text(topic)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedTopics.contains(topic) ? .black : .white)
                                                .lineLimit(1)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .fill(selectedTopics.contains(topic) ? Color.white : Color.white.opacity(0.1))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                        )
                                                )
                                        }
                                    }
                                }
                                .padding(.trailing, 40)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 1
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                        )
                }
                
                Button(action: {
                    completeOnboarding()
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    private func NotificationPermissionScreen() -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Stay Updated")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Get daily reminders to discover amazing Wikipedia articles")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("Daily reminders at 8:00, 13:00, 18:00, and 23:00")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("Notifications in your selected language")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("You can disable this anytime in Settings")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    requestNotificationPermission()
                }) {
                    Text("Allow Notifications")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 2
                    }
                }) {
                    Text("Skip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
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
    
    private func toggleTopic(_ topic: String) {
        if topic == "All Topics" {
            if selectedTopics.contains("All Topics") {
                selectedTopics.removeAll()
            } else {
                selectedTopics = Set(topics)
            }
        } else {
            selectedTopics.remove("All Topics")
            if selectedTopics.contains(topic) {
                selectedTopics.remove(topic)
            } else {
                selectedTopics.insert(topic)
            }
            
            if selectedTopics.isEmpty {
                selectedTopics.insert("All Topics")
            } else if selectedTopics.count == topics.count - 1 {
                selectedTopics.insert("All Topics")
            }
        }
    }
    
    private func completeOnboarding() {
        // Save preferences to UserDefaults or app state
        UserDefaults.standard.set(selectedAppLanguage, forKey: "selectedAppLanguage")
        UserDefaults.standard.set(selectedArticleLanguage, forKey: "selectedArticleLanguage")
        UserDefaults.standard.set(Array(selectedTopics), forKey: "selectedTopics")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        showOnboarding = false
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}