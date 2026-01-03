import SwiftUI

struct NotificationPermissionView: View {
    let onAllow: () -> Void

    
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
                

                
                Text("Get daily reminders to discover amazing Wikipedia articles")
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
                    Text("Daily reminders at 8:00, 13:00, 18:00, and 23:00")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("Notifications in your selected language")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("You can disable this anytime in Settings")
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
