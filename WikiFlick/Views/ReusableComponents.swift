import SwiftUI

// MARK: - Button Components

struct CircularButton: View {
    let icon: String
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    
    init(
        icon: String,
        action: @escaping () -> Void,
        backgroundColor: Color = Color.black.opacity(0.7),
        foregroundColor: Color = .white,
        size: CGFloat = 44
    ) {
        self.icon = icon
        self.action = action
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.size = size
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        backgroundColor: Color = .white,
        foregroundColor: Color = .black,
        cornerRadius: CGFloat = 12
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    LoadingIndicatorView()
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
        }
        .disabled(isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    LoadingIndicatorView()
                        .scaleEffect(0.6)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .disabled(isLoading)
    }
}

// MARK: - Card Components

struct ContentCard<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.black.opacity(0.85),
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Search Components

struct SearchBar: View {
    @Binding var searchText: String
    let placeholder: String
    let onSearchTextChanged: ((String) -> Void)?
    let onCancel: (() -> Void)?
    
    init(
        searchText: Binding<String>,
        placeholder: String = "Search...",
        onSearchTextChanged: ((String) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.onSearchTextChanged = onSearchTextChanged
        self.onCancel = onCancel
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 16))
                
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .accentColor(.white)
                    .onChange(of: searchText) { newValue in
                        onSearchTextChanged?(newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                    )
            )
            
            if let onCancel = onCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
        }
    }
}

// MARK: - List Components

struct SelectableListItem: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let flag: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        flag: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.flag = flag
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let flag = flag {
                    Text(flag)
                        .font(.system(size: 20))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}



// MARK: - View Extensions

extension View {
    func backdrop(blur: CGFloat) -> some View {
        self.background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .blur(radius: blur)
        )
    }
    
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.7))
                .backdrop(blur: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}