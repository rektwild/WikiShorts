import SwiftUI

struct OnboardingTopicSelectionView: View {
    @Binding var selectedTopics: Set<String>
    let topics: [String]
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Text("Select topics you're interested in (max 5)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                if selectedTopics.count > 0 && !selectedTopics.contains("All Topics") {
                    Text("\(selectedTopics.count)/5 selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            VStack(spacing: 12) {
                Text("Interested Topics")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                let chunkedTopics = topics.chunked(into: 3)
                
                VStack(spacing: 12) {
                    ForEach(0..<chunkedTopics.count, id: \.self) { rowIndex in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(chunkedTopics[rowIndex], id: \.self) { topic in
                                    Button(action: {
                                        toggleTopic(topic)
                                    }) {
                                        Text(topic)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(selectedTopics.contains(topic) ? .black : .white)
                                            .lineLimit(1)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(selectedTopics.contains(topic) ? Color.white : Color.white.opacity(0.1))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                    )
                                            )
                                    }
                                }
                            }
                            .padding(.trailing, 40)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
    }
    
    private func toggleTopic(_ topic: String) {
        if topic == "All Topics" {
            // Toggle All Topics selection
            if selectedTopics.contains("All Topics") {
                selectedTopics = ["All Topics"]  // Keep at least All Topics selected
            } else {
                selectedTopics = ["All Topics"]  // Select only All Topics
            }
        } else {
            // If All Topics is selected, clear it and select the new topic
            if selectedTopics.contains("All Topics") {
                selectedTopics.removeAll()
                selectedTopics.insert(topic)
            } else if selectedTopics.contains(topic) {
                // Remove the topic
                selectedTopics.remove(topic)
                // If no topics selected, default to All Topics
                if selectedTopics.isEmpty {
                    selectedTopics.insert("All Topics")
                }
            } else {
                // Check if we've reached the limit of 5 topics
                if selectedTopics.count < 5 {
                    selectedTopics.insert(topic)
                }
            }
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingTopicSelectionView(
            selectedTopics: .constant(["All Topics"]),
            topics: ["All Topics", "Science", "History", "Technology", "Art", "Sports"],
            onGetStarted: {}
        )
    }
}
