import SwiftUI
import StoreKit

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var articleLanguageManager = ArticleLanguageManager.shared
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var showingLanguageSelection = false
    @State private var showingArticleLanguageSelection = false
    @State private var showingPaywall = false
    private let languages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
    
    var body: some View {
        NavigationView {
            List {
                Section(languageManager.localizedString(key: "status")) {
                    HStack {
                        Image(systemName: storeManager.isPurchased("wiki_m") ? "crown.fill" : "person.circle")
                            .foregroundColor(storeManager.isPurchased("wiki_m") ? .yellow : .gray)
                        Text(languageManager.localizedString(key: "account_status"))
                        Spacer()
                        Text(storeManager.isPurchased("wiki_m") ? languageManager.localizedString(key: "pro") : languageManager.localizedString(key: "free"))
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
                
                // Cache Statistics Section
                Section(header: Text(languageManager.localizedString(key: "cache"))) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "internaldrive")
                            Text(languageManager.localizedString(key: "image_cache"))
                            Spacer()
                            let stats = ArticleCacheManager.shared.getCacheStatistics()
                            Text("\(stats.imageCacheCount) \(languageManager.localizedString(key: "cache_items"))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "doc.text")
                            Text(languageManager.localizedString(key: "article_cache"))
                            Spacer()
                            let stats = ArticleCacheManager.shared.getCacheStatistics()
                            Text("\(stats.articleCacheCount) \(languageManager.localizedString(key: "cache_items"))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        HStack {
                            Image(systemName: "cylinder")
                            Text(languageManager.localizedString(key: "memory_limit"))
                            Spacer()
                            let stats = ArticleCacheManager.shared.getCacheStatistics()
                            Text("\(stats.imageCacheCostLimit / (1024 * 1024))MB")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        ArticleCacheManager.shared.clearImageCache()
                        ArticleCacheManager.shared.clearArticleCache()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text(languageManager.localizedString(key: "clear_all_cache"))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
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
                        Text("1.1")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        requestAppReview()
                    }) {
                        HStack {
                            Image(systemName: "star")
                            Text(languageManager.localizedString(key: "rate_app"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
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
        .sheet(isPresented: $showingArticleLanguageSelection) {
            ArticleLanguageSelectionView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isPresented: $showingPaywall)
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadSettings() {
    }
    
    private func saveSettings() {
    }
    

    private func requestAppReview() {
        // Use the ReviewRequestManager for immediate review request
        ReviewRequestManager.shared.requestReviewImmediately()
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
                    Button(languageManager.localizedString(key: "cancel")) {
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
        .environmentObject(StoreManager())
}