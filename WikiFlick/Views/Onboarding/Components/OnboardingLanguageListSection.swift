import SwiftUI

struct OnboardingLanguageListSection: View {
    let title: String
    let languages: [AppLanguage]
    @Binding var selectedLanguage: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.horizontal, 16)
            
            languageList
        }
    }
    
    private var languageList: some View {
        LazyVStack(spacing: 0) {
            ForEach(languages, id: \.self) { language in
                languageButton(for: language)
                
                Divider()
                    .padding(.leading, 72)
                    .opacity(0.5)
            }
        }
        .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1), lineWidth: 1)
                .padding(.horizontal, 16)
        )
    }
    
    private func languageButton(for language: AppLanguage) -> some View {
        Button(action: {
            HapticManager.shared.itemSelected()
            selectedLanguage = language
        }) {
            HStack(spacing: 16) {
                languageFlag(for: language)
                languageText(for: language)
                Spacer()
                selectionIndicator(for: language)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // Makes entire row tappable
            .background(
                language == selectedLanguage ? Color.primaryBlue.opacity(0.05) : Color.clear
            )
        }
        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle for better tap handling
        .accessibilityLabel("\(language.displayName), \(language.englishName)")
        .accessibilityHint(language == selectedLanguage ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(language == selectedLanguage ? .isSelected : [])
    }
    
    private func languageFlag(for language: AppLanguage) -> some View {
        Text(language.flag)
            .font(.system(size: 24))
            .frame(width: 40, height: 40)
            .background(colorScheme == .dark ? Color.surfaceDark : Color.gray.opacity(0.05))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
    
    private func languageText(for language: AppLanguage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(language.displayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(language == selectedLanguage ? Color.primaryBlue : (colorScheme == .dark ? .white : .black))
            Text(language.englishName)
                .font(.system(size: 12))
                .foregroundColor(language == selectedLanguage ? Color.primaryBlue.opacity(0.7) : .gray)
        }
    }
    
    private func selectionIndicator(for language: AppLanguage) -> some View {
        ZStack {
            if language == selectedLanguage {
                Circle()
                    .fill(Color.primaryBlue)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.primaryBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                
                checkmarkImage
            } else {
                Circle()
                    .strokeBorder(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var checkmarkImage: some View {
        if #available(iOS 17.0, *) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .symbolEffect(.bounce, value: selectedLanguage)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingLanguageListSection(
        title: "All Languages",
        languages: [.english, .turkish, .german],
        selectedLanguage: .constant(.english)
    )
}
