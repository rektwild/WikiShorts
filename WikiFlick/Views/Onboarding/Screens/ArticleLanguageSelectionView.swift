import SwiftUI

struct OnboardingArticleLanguageSelectionView: View {
    @Binding var selectedLanguage: AppLanguage
    let availableLanguages: [AppLanguage]
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    let onContinue: () -> Void
    
    private var filteredLanguages: [AppLanguage] {
        if searchText.isEmpty {
            return availableLanguages
        } else {
            return availableLanguages.filter { language in
                language.displayName.localizedCaseInsensitiveContains(searchText) ||
                language.rawValue.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            OnboardingSearchBar(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Popular Section
                    if searchText.isEmpty {
                        PopularLanguagesSection(selectedLanguage: $selectedLanguage)
                    }
                    
                    // All Languages Section
                    OnboardingLanguageListSection(
                        title: "All Languages",
                        languages: filteredLanguages,
                        selectedLanguage: $selectedLanguage
                    )
                }
                .padding(.bottom, 100) // Space for sticky footer
            }
        }
        .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
        .overlay(alignment: .bottom) {
            // Sticky Footer
            OnboardingStickyFooter(action: onContinue)
        }
    }
}

#Preview {
    OnboardingArticleLanguageSelectionView(
        selectedLanguage: .constant(.english),
        availableLanguages: [.english, .turkish, .german],
        onContinue: {}
    )
}
