import SwiftUI

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var showingLanguageSelection = false
    @State private var selectedTopics: Set<String> = ["all_topics"]
    @State private var showingTopicSelection = false
    @State private var selectedArticleLanguage = "English"
    @State private var showingArticleLanguageSelection = false
    @State private var showingPaywall = false
    @StateObject private var storeManager = StoreManager()
    
    private let languages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
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
                        Toggle("", isOn: .constant(true))
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
                            Text(selectedArticleLanguage)
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
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingTopicSelection) {
            TopicSelectionView(selectedTopics: $selectedTopics)
        }
        .sheet(isPresented: $showingArticleLanguageSelection) {
            ArticleLanguageSelectionView(selectedArticleLanguage: $selectedArticleLanguage)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadSettings() {
        selectedArticleLanguage = UserDefaults.standard.string(forKey: "selectedArticleLanguage") ?? AppLanguage.english.displayName
        
        if let topicsArray = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] {
            selectedTopics = Set(topicsArray)
        }
        
        if selectedTopics.isEmpty {
            selectedTopics = ["all_topics"]
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedArticleLanguage, forKey: "selectedArticleLanguage")
        UserDefaults.standard.set(Array(selectedTopics), forKey: "selectedTopics")
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
    
    private let topicKeys = [
        "all_topics",
        "general_reference", 
        "culture_and_arts",
        "geography_and_places",
        "health_and_fitness",
        "history_and_events",
        "human_activities",
        "mathematics_and_logic",
        "natural_and_physical_sciences",
        "people_and_self",
        "philosophy_and_thinking",
        "religion_and_belief_systems",
        "society_and_social_sciences",
        "technology_and_applied_sciences"
    ]
    
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
                            if selectedTopics.contains("all_topics") {
                                selectedTopics.removeAll()
                            } else {
                                selectedTopics = Set(topicKeys)
                            }
                        } else {
                            selectedTopics.remove("all_topics")
                            if selectedTopics.contains(topic.key) {
                                selectedTopics.remove(topic.key)
                            } else {
                                selectedTopics.insert(topic.key)
                            }
                            
                            if selectedTopics.isEmpty {
                                selectedTopics.insert("all_topics")
                            } else if selectedTopics.count == topicKeys.count - 1 {
                                selectedTopics.insert("all_topics")
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
                        UserDefaults.standard.set(Array(selectedTopics), forKey: "selectedTopics")
                        NotificationCenter.default.post(name: .settingsChanged, object: nil)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ArticleLanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedArticleLanguage: String
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
                            selectedArticleLanguage = language.displayName
                            UserDefaults.standard.set(language.displayName, forKey: "selectedArticleLanguage")
                            NotificationCenter.default.post(name: .settingsChanged, object: nil)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                                Spacer()
                                if language.displayName == selectedArticleLanguage {
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