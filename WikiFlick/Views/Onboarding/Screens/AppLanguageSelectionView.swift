import SwiftUI

struct AppLanguageSelectionView: View {
    @Binding var selectedLanguage: AppLanguage
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Popular Section
                if searchText.isEmpty {
                    PopularLanguagesSection(selectedLanguage: $selectedLanguage)
                        .padding(.top, 16)
                }
                
                // All Languages Section
                OnboardingLanguageListSection(
                    title: AppLanguageManager.shared.localizedString(key: "all_languages"),
                    languages: filteredLanguages,
                    selectedLanguage: $selectedLanguage
                )
            }
            .padding(.bottom, 100) // Space for sticky footer
        }
        .background(colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
        .overlay(alignment: .bottom) {
            // Sticky Footer
            OnboardingStickyFooter(action: onContinue)
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(AppLanguageManager.shared.localizedString(key: "search_languages")))
    }
}

#Preview {
    AppLanguageSelectionView(
        selectedLanguage: .constant(.english),
        onContinue: {}
    )
}
