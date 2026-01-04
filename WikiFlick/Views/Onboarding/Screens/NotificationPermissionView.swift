import SwiftUI

struct NotificationPermissionView: View {
    let onAllow: () -> Void
    @StateObject private var languageManager = AppLanguageManager.shared

    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                if #available(iOS 17.0, *) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse.byLayer, options: .repeating)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                }
                

                
                Text(languageManager.localizedString(key: "daily_reminders_setup"))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text(languageManager.localizedString(key: "daily_reminders_detail"))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text(languageManager.localizedString(key: "notifications_language"))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text(languageManager.localizedString(key: "disable_anytime"))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
        }
        .overlay(alignment: .bottom) {
            OnboardingStickyFooter(action: {
                HapticManager.shared.buttonPressed()
                onAllow()
            })
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NotificationPermissionView(
            onAllow: {}
        )
    }
}
