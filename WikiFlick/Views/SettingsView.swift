import SwiftUI

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var articleLanguageManager = ArticleLanguageManager.shared
    @State private var showingLanguageSelection = false
    @State private var selectedTopics: Set<String> = []
    @State private var showingTopicSelection = false
    @State private var showingArticleLanguageSelection = false
    @State private var showingPaywall = false
    @StateObject private var storeManager = StoreManager()
    
    private let languages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
    private let topics = TopicManager.topicDisplayNames
    
    var body: some View {
        NavigationView {
            List {
                Section(languageManager.localizedString(key: "status")) {
                    HStack {
                        Image(systemName: storeManager.isPurchased("wiki_m") ? "crown.fill" : "person.circle")
                            .foregroundColor(storeManager.isPurchased("wiki_m") ? .yellow : .gray)
                        Text(languageManager.localizedString(key: "account_status"))
                        Spacer()
                        Text(storeManager.isPurchased("wiki_m") ? "PRO" : "FREE")
                            .foregroundColor(storeManager.isPurchased("wiki_m") ? .yellow : .secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    if !storeManager.isPurchased("wiki_m") {
                        Button(action: {
                            showingPaywall = true
                        }) {
                            HStack {
                                Image(systemName: "crown")
                                    .foregroundColor(.yellow)
                                Text(languageManager.localizedString(key: "go_premium"))
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section(languageManager.localizedString(key: "preferences")) {
                    HStack {
                        Image(systemName: "bell")
                        Text(languageManager.localizedString(key: "notifications"))
                        Spacer()
                        Toggle("", isOn: $notificationManager.isNotificationEnabled)
                    }
                    
                    Button(action: {
                        showingLanguageSelection = true
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text(languageManager.localizedString(key: "language"))
                            Spacer()
                            Text(languageManager.currentLanguage.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(languageManager.localizedString(key: "wiki_article_preferences")) {
                    Button(action: {
                        showingTopicSelection = true
                    }) {
                        HStack {
                            Image(systemName: "book")
                            Text(languageManager.localizedString(key: "topic"))
                            Spacer()
                            Text(getTopicDisplayText())
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        showingArticleLanguageSelection = true
                    }) {
                        HStack {
                            Image(systemName: "globe.americas")
                            Text(languageManager.localizedString(key: "article_language"))
                            Spacer()
                            Text(articleLanguageManager.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(languageManager.localizedString(key: "legal")) {
                    Button(action: {
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text(languageManager.localizedString(key: "terms_of_service"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        if let url = URL(string: "https://www.freeprivacypolicy.com/live/affd7171-b413-4bef-bbad-b4ec83a5fa1d") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text(languageManager.localizedString(key: "privacy_policy"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(languageManager.localizedString(key: "about")) {
                    HStack {
                        Image(systemName: "info.circle")
                        Text(languageManager.localizedString(key: "app_version"))
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star")
                        Text(languageManager.localizedString(key: "rate_app"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(languageManager.localizedString(key: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString(key: "done")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSettings()
            Task {
                await storeManager.loadProducts()
            }
        }
        .onDisappear {
            saveSettings()
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingTopicSelection) {
            TopicSelectionView(selectedTopics: $selectedTopics)
        }
        .sheet(isPresented: $showingArticleLanguageSelection) {
            ArticleLanguageSelectionView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadSettings() {
        // Load saved topics using TopicManager
        selectedTopics = TopicManager.getSavedTopicsAsKeys()
    }
    
    private func saveSettings() {
        // Save topics using TopicManager
        TopicManager.saveTopicsFromKeys(selectedTopics)
    }
    
    private func getTopicDisplayText() -> String {
        if selectedTopics.count == 1, let firstTopic = selectedTopics.first {
            return languageManager.localizedString(key: firstTopic)
        } else {
            return "\(selectedTopics.count) \(languageManager.localizedString(key: "selected"))"
        }
    }
}

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var searchText = ""
    
    private var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return AppLanguage.allCases
        } else {
            return AppLanguage.allCases.filter { language in
                language.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField(languageManager.localizedString(key: "search"), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                List {
                    ForEach(filteredLanguages, id: \.self) { language in
                        Button(action: {
                            languageManager.currentLanguage = language
                            NotificationCenter.default.post(name: .settingsChanged, object: nil)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                                Spacer()
                                if language == languageManager.currentLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(languageManager.localizedString(key: "language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TopicSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTopics: Set<String>
    @StateObject private var languageManager = AppLanguageManager.shared
    
    private let topicKeys = TopicManager.topicKeys
    
    private var localizedTopics: [(key: String, display: String)] {
        return topicKeys.map { key in
            (key: key, display: languageManager.localizedString(key: key))
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(localizedTopics, id: \.key) { topic in
                    Button(action: {
                        if topic.key == "all_topics" {
                            // Toggle All Topics selection
                            if selectedTopics.contains("all_topics") {
                                selectedTopics = ["all_topics"]  // Keep at least All Topics selected
                            } else {
                                selectedTopics = ["all_topics"]  // Select only All Topics
                            }
                        } else {
                            // If All Topics is selected, clear it and select the new topic
                            if selectedTopics.contains("all_topics") {
                                selectedTopics.removeAll()
                                selectedTopics.insert(topic.key)
                            } else if selectedTopics.contains(topic.key) {
                                // Remove the topic
                                selectedTopics.remove(topic.key)
                                // If no topics selected, default to All Topics
                                if selectedTopics.isEmpty {
                                    selectedTopics.insert("all_topics")
                                }
                            } else {
                                // Check if we've reached the limit of 5 topics
                                if selectedTopics.count < TopicManager.maxTopicSelection {
                                    selectedTopics.insert(topic.key)
                                }
                            }
                        }
                    }) {
                        HStack {
                            Text(topic.display)
                            Spacer()
                            if selectedTopics.contains(topic.key) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(AppLanguageManager.shared.localizedString(key: "topics"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(AppLanguageManager.shared.localizedString(key: "done")) {
                        TopicManager.saveTopicsFromKeys(selectedTopics)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedTopics.contains("all_topics") && selectedTopics.count > 0 {
                        Text("\(selectedTopics.count)/\(TopicManager.maxTopicSelection)")
                            .foregroundColor(selectedTopics.count >= TopicManager.maxTopicSelection ? .orange : .secondary)
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ArticleLanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var articleLanguageManager = ArticleLanguageManager.shared
    @State private var searchText = ""
    
    private var filteredLanguages: [AppLanguage] {
        return articleLanguageManager.filteredLanguages(searchText: searchText)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField(languageManager.localizedString(key: "search"), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                List {
                    ForEach(filteredLanguages, id: \.self) { language in
                        Button(action: {
                            articleLanguageManager.selectLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                                Spacer()
                                if language == articleLanguageManager.selectedLanguage {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle(languageManager.localizedString(key: "article_language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString(key: "cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SettingsView()
}