import SwiftUI

struct AppLanguageSelectionView: View {
    @Binding var selectedLanguage: AppLanguage
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme
    let onContinue: () -> Void
    
    private var filteredLanguages: [AppLanguage] {
        let allLanguages = AppLanguage.allCases.sorted { $0.displayName < $1.displayName }
        if searchText.isEmpty {
            return allLanguages
        } else {
            return allLanguages.filter { language in
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
                    // Popular Section (Only if not searching)
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
    AppLanguageSelectionView(
        selectedLanguage: .constant(.english),
        onContinue: {}
    )
}
