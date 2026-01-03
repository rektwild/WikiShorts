import SwiftUI

struct OnboardingTopicSelectionView: View {
    @Binding var selectedTopics: Set<String>
    let topics: [String]
    let onGetStarted: () -> Void
    
    // Environment values for dismiss if needed, though this is likely part of a flow
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        content
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            // Native List for Topics
            List {
                Section {
                    ForEach(topics, id: \.self) { topic in
                        Button(action: {
                            toggleTopic(topic)
                        }) {
                            HStack {
                                Text(topic)
                                    .font(.title3) // ~20px/xl equivalent
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Custom Checkbox
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                    
                                    if selectedTopics.contains(topic) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue) // Primary color
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            }
                            .contentShape(Rectangle()) // Make entire row tappable
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain) // Remove default button highlighting
                        .listRowSeparator(.visible) // Native separators
                    }
                }
                
                // Bottom spacing for sticky footer
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain) // Removes default list background/padding for cleaner look
        }
        .overlay(alignment: .bottom) {
            OnboardingStickyFooter(action: onGetStarted)
        }
        .navigationTitle("What interests you?")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func toggleTopic(_ topic: String) {
        if selectedTopics.contains(topic) {
            selectedTopics.remove(topic)
            HapticManager.shared.itemDeselected()
        } else {
            if selectedTopics.count < 5 {
                selectedTopics.insert(topic)
                HapticManager.shared.itemSelected()
            } else {
                HapticManager.shared.limitReached()
            }
        }
    }
}

#Preview {
    ZStack {
        // Preview background
        Color(UIColor.systemBackground).ignoresSafeArea()
        
        OnboardingTopicSelectionView(
            selectedTopics: .constant(["Technology", "Design", "Science"]),
            topics: ["Politics", "Technology", "Design", "Economics", "Science", "Culture", "Philosophy", "Gastronomy", "Space"],
            onGetStarted: {}
        )
    }
}

