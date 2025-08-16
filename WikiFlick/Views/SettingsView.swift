import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage = "English"
    @State private var showingLanguageSelection = false
    @State private var selectedTopics: Set<String> = ["All Topics"]
    @State private var showingTopicSelection = false
    @State private var selectedArticleLanguage = "English"
    @State private var showingArticleLanguageSelection = false
    
    private let languages = ["English", "Türkçe", "Deutsch", "Français", "Italiano", "中文"]
    private let topics = ["All Topics", "Science", "History", "Technology", "Sports", "Arts", "Geography", "Biography"]
    private let articleLanguages = ["English", "Turkish", "German", "French", "Italian", "Chinese", "Spanish", "Japanese"]
    
    var body: some View {
        NavigationView {
            List {
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
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView(selectedLanguage: $selectedLanguage)
        }
        .sheet(isPresented: $showingTopicSelection) {
            TopicSelectionView(selectedTopics: $selectedTopics)
        }
        .sheet(isPresented: $showingArticleLanguageSelection) {
            ArticleLanguageSelectionView(selectedArticleLanguage: $selectedArticleLanguage)
        }
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
    
    private let topics = ["All Topics", "Science", "History", "Technology", "Sports", "Arts", "Geography", "Biography"]
    
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