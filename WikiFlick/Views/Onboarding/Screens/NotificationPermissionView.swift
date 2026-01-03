import SwiftUI

struct NotificationPermissionView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Stay Updated")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
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
            
            VStack(spacing: 12) {
                Button(action: onAllow) {
                    Text("Allow Notifications")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                }
                
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NotificationPermissionView(
            onAllow: {},
            onSkip: {}
        )
    }
}
