import SwiftUI

struct OnboardingStickyFooter: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack {
                Button(action: action) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primaryBlue)
                    .cornerRadius(12)
                    .shadow(color: Color.primaryBlue.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .padding(.top, 20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight).opacity(0),
                        (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight).opacity(0.9),
                        (colorScheme == .dark ? Color.backgroundDark : Color.backgroundLight)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        OnboardingStickyFooter(action: {})
    }
}
