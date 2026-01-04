//
//  TodayView.swift
//  WikiFlick
//
//  View displaying "On This Day" events in a vertical timeline
//

import SwiftUI

struct TodayView: View {
    
    // MARK: - State
    
    @StateObject private var onThisDayService = OnThisDayService()
    @State private var selectedEvent: OnThisDayEvent?
    @State private var showingEventDetail = false
    
    // MARK: - Computed Properties
    
    private var currentDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: AppLanguageManager.shared.currentLanguage.rawValue)
        return formatter.string(from: Date())
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if onThisDayService.isLoading && onThisDayService.events.isEmpty {
                    loadingView
                } else if let errorMessage = onThisDayService.errorMessage, onThisDayService.events.isEmpty {
                    errorView(errorMessage)
                } else if onThisDayService.events.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            headerView
                                .padding(.horizontal)
                                .padding(.top, 16)
                            
                            // Timeline
                            timelineView
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("today_title".localized)
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await onThisDayService.refreshEvents()
            }
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    EventDetailView(event: event)
                }
            }
        }
        .task {
            await onThisDayService.fetchOnThisDayEvents()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentDate.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("today_subtitle".localized)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        VStack(spacing: 0) {
            ForEach(Array(onThisDayService.events.enumerated()), id: \.element) { index, event in
                TimelineEventRow(
                    event: event,
                    isLast: index == onThisDayService.events.count - 1
                ) {
                    selectedEvent = event
                    showingEventDetail = true
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("loading_events".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("error_loading_events".localized)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await onThisDayService.fetchOnThisDayEvents()
                }
            }) {
                Text("retry".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
        }
        .padding()
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("no_events_today".localized)
                .font(.headline)
            
            Text("no_events_description".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Timeline Event Row

struct TimelineEventRow: View {
    
    let event: OnThisDayEvent
    let isLast: Bool
    let onTap: () -> Void
    
    @State private var thumbnailImage: UIImage?
    // Environment to detect color scheme for shadow adjustments
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and dot
            timelineIndicator
            
            // Event content
            eventContent
        }
        .padding(.bottom, 24) // Adds spacing between events for "breathing room"
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .task {
            await loadThumbnail()
        }
    }
    
    // MARK: - Timeline Indicator
    
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // Node
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color(UIColor.systemGroupedBackground), lineWidth: 3)
                )
                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .zIndex(1) // Ensure dot is above the line
            
            // Continuous Line
            if !isLast {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.1)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, -2) // Connect to dot
                    .padding(.bottom, -26) // Extend to next dot visually
            }
        }
        .frame(width: 16) // Fixed width for alignment
    }
    
    // MARK: - Event Content
    
    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Year
            HStack(alignment: .center) {
                Text(String(event.year))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            HStack(alignment: .top, spacing: 12) {
                // Text content
                Text(event.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Thumbnail (small, right aligned if exists)
                if thumbnailImage != nil || event.pages.first?.thumbnail?.source != nil {
                     thumbnailView
                }
            }
            
            // Related tag pages (simplified)
            if !event.pages.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(event.pages.prefix(3), id: \.title) { page in
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.caption2)
                                Text(page.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                        }
                        
                        if event.pages.count > 3 {
                             Text("+\(event.pages.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
    
    // MARK: - Thumbnail View
    
    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let thumbnailURL = event.pages.first?.thumbnail?.source {
                AsyncImage(url: URL(string: thumbnailURL)) { phase in
                    switch phase {
                    case .empty:
                        Color.secondary.opacity(0.1)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        Color.secondary.opacity(0.1)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
    
    // MARK: - Load Thumbnail
    
    private func loadThumbnail() async {
        guard let thumbnailURL = event.pages.first?.thumbnail?.source,
              let url = URL(string: thumbnailURL) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.thumbnailImage = image
                }
            }
        } catch {
            print("Failed to load thumbnail: \(error)")
        }
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    
    let event: OnThisDayEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Year header
                    yearHeader
                    
                    // Thumbnail
                    if let thumbnailURL = event.pages.first?.thumbnail?.source {
                        eventThumbnail(thumbnailURL)
                    }
                    
                    // Banner Ad
                    if !AdMobManager.shared.isPremiumUser {
                        BannerAdView(adUnitID: AdMobManager.shared.bannerAdUnitID)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Event text
                    eventText
                    
                    // Related pages
                    if !event.pages.isEmpty {
                        relatedPages
                    }
                }
                .padding()
            }
            .navigationTitle(String(event.year))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Year Header
    
    private var yearHeader: some View {
        HStack {
            Text(String(event.year))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Spacer()
        }
    }
    
    // MARK: - Event Thumbnail
    
    private func eventThumbnail(_ urlString: String) -> some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(height: 200)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            case .failure:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            @unknown default:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Event Text
    
    private var eventText: some View {
        Text(event.text)
            .font(.body)
            .lineSpacing(6)
    }
    
    // MARK: - Related Pages
    
    private var relatedPages: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("related_pages".localized)
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(event.pages, id: \.title) { page in
                    PageRow(page: page)
                }
            }
        }
    }
}

// MARK: - Page Row

struct PageRow: View {
    
    let page: WikipediaPage
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailURL = page.thumbnail?.source {
                AsyncImage(url: URL(string: thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.headline)
                
                if let description = page.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    TodayView()
}
