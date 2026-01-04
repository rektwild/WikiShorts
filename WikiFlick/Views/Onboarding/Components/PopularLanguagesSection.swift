import SwiftUI

struct PopularLanguagesSection: View {
    @Binding var selectedLanguage: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var languageManager = AppLanguageManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localizedString(key: "popular"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppLanguage.popularLanguages, id: \.self) { language in
                        Button(action: {
                            HapticManager.shared.itemSelected()
                            selectedLanguage = language
                        }) {
                            HStack(spacing: 8) {
                                Text(language.flag)
                                    .font(.system(size: 24))
                                Text(language.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                
                                if language == selectedLanguage {
                                    if #available(iOS 17.0, *) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .symbolEffect(.bounce, value: selectedLanguage)
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(language == selectedLanguage ? Color.primaryBlue : (colorScheme == .dark ? Color.surfaceDark : Color.white))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        language == selectedLanguage ? Color.clear : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.2)),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: language == selectedLanguage ? Color.primaryBlue.opacity(0.2) : Color.clear, radius: 4, x: 0, y: 2)
                            .foregroundColor(language == selectedLanguage ? .white : (colorScheme == .dark ? .gray : .black.opacity(0.7)))
                        }
                        .accessibilityLabel(language.localizedName)
                        .accessibilityHint(language == selectedLanguage ? languageManager.localizedString(key: "selected_accessibility_hint") : languageManager.localizedString(key: "double_tap_to_select"))
                        .accessibilityAddTraits(language == selectedLanguage ? .isSelected : [])
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    PopularLanguagesSection(selectedLanguage: .constant(.english))
}
