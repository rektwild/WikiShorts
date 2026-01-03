import SwiftUI

// MARK: - Search Result Card View

struct SearchResultCardView: View {
    let searchResult: SearchResult
    let onTap: () -> Void
    @StateObject private var languageManager = AppLanguageManager.shared
    private let imageLoadingService = ImageLoadingService.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Image thumbnail
                imageView
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(searchResult.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    if !searchResult.description.isEmpty && searchResult.description != "No description available" {
                        Text(searchResult.description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    } else {
                        Text("Brief article summary...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Chevron with animation
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .scaleEffect(isPressed ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(isPressed ? Color.white.opacity(0.1) : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    private var imageView: some View {
        Group {
            if let imageURL = searchResult.displayImageURL, let url = URL(string: imageURL) {
                AsyncImageView(
                    urlString: url.absoluteString,
                    imageLoadingService: imageLoadingService
                ) {
                    placeholderImage
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderImage
            }
        }
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "doc.text")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
            )
    }
}

// MARK: - Enhanced Search Results List

struct SearchResultsListView: View {
    let searchResults: [SearchResult]
    let onResultSelected: (SearchResult) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchResults.prefix(5).enumerated()), id: \.element.id) { index, result in
                SearchResultCardView(searchResult: result) {
                    onResultSelected(result)
                }
                
                if index < min(4, searchResults.count - 1) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(searchResultsBackground)
    }
    
    private var searchResultsBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Enhanced Search Bar

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var isActive: Bool
    let onCancel: () -> Void
    let onClear: () -> Void
    @StateObject private var languageManager = AppLanguageManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            searchInputField
            
            if isActive || !searchText.isEmpty {
                cancelButton
                    .transition(.move(edge: .trailing))
            }
        }
    }
    
    private var searchInputField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
            
            TextField(
                languageManager.localizedString(key: "search_wikipedia"),
                text: $searchText
            )
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(.primary)
            .font(.system(size: 17))
            
            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }
    
    private var cancelButton: some View {
        Button(languageManager.localizedString(key: "cancel")) {
            onCancel()
        }
        .foregroundColor(.blue)
    }
}

// MARK: - Search History View

struct SearchHistoryView: View {
    let searchHistory: [SearchHistory]
    let onHistoryItemTap: (String) -> Void
    let onClearHistory: () -> Void
    @StateObject private var languageManager = AppLanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button("Clear") {
                    onClearHistory()
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.5))
            
            // History items
            ForEach(searchHistory.prefix(5)) { item in
                Button(action: {
                    onHistoryItemTap(item.query)
                }) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text(item.query)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
                
                if item.id != searchHistory.last?.id {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
            }
        }
        .background(historyBackground)
    }
    
    private var historyBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SearchResultCardView(
            searchResult: SearchResult(
                title: "Sample Article",
                description: "This is a sample description for testing",
                url: "https://example.com",
                thumbnail: Thumbnail(source: "https://example.com/thumb.jpg", width: 200, height: 200),
                pageId: 123,
                imageURL: nil as String?
            ),
            onTap: {}
        )
        
        SearchBarView(
            searchText: .constant("Sample search"),
            isActive: .constant(true),
            onCancel: {},
            onClear: {}
        )
    }
    .background(Color.black)
}