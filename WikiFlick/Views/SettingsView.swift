import SwiftUI

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage = "English"
    @State private var showingLanguageSelection = false
    @State private var selectedTopics: Set<String> = ["All Topics"]
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
    private let articleLanguages = ["English", "Turkish", "German", "French", "Italian", "Chinese", "Spanish", "Japanese"]
    
    var body: some View {
        NavigationView {
            List {
                Section("Status") {
                    HStack {
                        Image(systemName: storeManager.isPurchased("wiki_m") ? "crown.fill" : "person.circle")
                            .foregroundColor(storeManager.isPurchased("wiki_m") ? .yellow : .gray)
                        Text("Account Status")
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
                                Text("Go Premium")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section("Preferences") {
                    HStack {
                        Image(systemName: "bell")
                        Text("Notifications")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    
                    Button(action: {
                        showingLanguageSelection = true
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("App Language")
                            Spacer()
                            Text(selectedLanguage)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("Wiki Article Preferences") {
                    Button(action: {
                        showingTopicSelection = true
                    }) {
                        HStack {
                            Image(systemName: "book")
                            Text("Topic")
                            Spacer()
                            Text(selectedTopics.count == 1 ? selectedTopics.first! : "\(selectedTopics.count) selected")
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
                            Text("Article Language")
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
                
                Section("Legal") {
                    Button(action: {
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Service")
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
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star")
                        Text("Rate App")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
            LanguageSelectionView(selectedLanguage: $selectedLanguage)
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
        selectedLanguage = UserDefaults.standard.string(forKey: "selectedAppLanguage") ?? "English"
        selectedArticleLanguage = UserDefaults.standard.string(forKey: "selectedArticleLanguage") ?? "English"
        
        if let topicsArray = UserDefaults.standard.array(forKey: "selectedTopics") as? [String] {
            selectedTopics = Set(topicsArray)
        }
        
        if selectedTopics.isEmpty {
            selectedTopics = ["All Topics"]
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedLanguage, forKey: "selectedAppLanguage")
        UserDefaults.standard.set(selectedArticleLanguage, forKey: "selectedArticleLanguage")
        UserDefaults.standard.set(Array(selectedTopics), forKey: "selectedTopics")
    }
}

struct LanguageSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: String
    
    private let languages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(languages, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                        UserDefaults.standard.set(language, forKey: "selectedAppLanguage")
                        NotificationCenter.default.post(name: .settingsChanged, object: nil)
                        dismiss()
                    }) {
                        HStack {
                            Text(language)
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Language")
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
                ForEach(topics, id: \.self) { topic in
                    Button(action: {
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
                    }) {
                        HStack {
                            Text(topic)
                            Spacer()
                            if selectedTopics.contains(topic) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Topics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
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
    
    private let articleLanguages = ["English", "Turkish", "German", "French", "Italian", "Chinese", "Spanish", "Japanese"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(articleLanguages, id: \.self) { language in
                    Button(action: {
                        selectedArticleLanguage = language
                        UserDefaults.standard.set(language, forKey: "selectedArticleLanguage")
                        NotificationCenter.default.post(name: .settingsChanged, object: nil)
                        dismiss()
                    }) {
                        HStack {
                            Text(language)
                            Spacer()
                            if language == selectedArticleLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Article Language")
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

#Preview {
    SettingsView()
}