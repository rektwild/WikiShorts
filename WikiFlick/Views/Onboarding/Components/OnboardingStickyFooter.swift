import SwiftUI

struct OnboardingStickyFooter: View {
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Native Search Bar (if provided)

                
                // Native Button Style
                Button(action: {
                    HapticManager.shared.stepCompleted()
                    action()
                }) {
                    Text(AppLanguageManager.shared.localizedString(key: "continue"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.white)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint("Proceeds to the next onboarding step")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .padding(.top, 16)
            .background(Color.clear)
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        OnboardingStickyFooter(action: {})
    }
}


