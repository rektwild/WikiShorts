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
            
            LazyVStack(spacing: 0) {
                ForEach(languages, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                    }) {
                        HStack(spacing: 16) {
                            Text(language.flag)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(colorScheme == .dark ? Color.surfaceDark : Color.gray.opacity(0.05))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(language == selectedLanguage ? Color.primaryBlue : (colorScheme == .dark ? .white : .black))
                                Text(language.englishName)
                                    .font(.system(size: 12))
                                    .foregroundColor(language == selectedLanguage ? Color.primaryBlue.opacity(0.7) : .gray)
                            }
                            
                            Spacer()
                            
                            ZStack {
                                if language == selectedLanguage {
                                    Circle()
                                        .fill(Color.primaryBlue)
                                        .frame(width: 24, height: 24)
                                        .shadow(color: Color.primaryBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Circle()
                                        .strokeBorder(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            language == selectedLanguage ? Color.primaryBlue.opacity(0.05) : Color.clear
                        )
                    }
                    
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
    }
}

#Preview {
    OnboardingLanguageListSection(
        title: "All Languages",
        languages: [.english, .turkish, .german],
        selectedLanguage: .constant(.english)
    )
}
