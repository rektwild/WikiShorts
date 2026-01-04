//
//  OnThisDayModels.swift
//  WikiFlick
//
//  Created for "On This Day" feature
//

import Foundation

// MARK: - On This Day Response Models

/// Represents the complete response from Wikipedia's "On this day" API
struct OnThisDayResponse: Codable {
    let selected: [OnThisDayEvent]?
    let events: [OnThisDayEvent]?
    let births: [OnThisDayEvent]?
    let deaths: [OnThisDayEvent]?
    let holidays: [OnThisDayEvent]?
    
    enum CodingKeys: String, CodingKey {
        case selected, events, births, deaths, holidays
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Helper to decode [OnThisDayEvent] or handle {} (empty dict) as nil
        func decodeSafe(_ key: CodingKeys) -> [OnThisDayEvent]? {
            if let val = try? container.decode([OnThisDayEvent].self, forKey: key) {
                return val
            }
            // If decoding as array fails, check if it's an empty dictionary
            // We blindly assume if it's not an array, it might be the empty dict case,
            // or we just treat it as nil to prevent crash.
            // If the user wants to be strict: try? container.decode([String:String].self, forKey: key)
            return nil
        }
        
        selected = decodeSafe(.selected)
        events = decodeSafe(.events)
        births = decodeSafe(.births)
        deaths = decodeSafe(.deaths)
        holidays = decodeSafe(.holidays)
    }
    
    init(selected: [OnThisDayEvent]?, events: [OnThisDayEvent]?, births: [OnThisDayEvent]?, deaths: [OnThisDayEvent]?, holidays: [OnThisDayEvent]?) {
        self.selected = selected
        self.events = events
        self.births = births
        self.deaths = deaths
        self.holidays = holidays
    }
    
    /// Combines all event types into a single sorted array
    var allEvents: [OnThisDayEvent] {
        var combined: [OnThisDayEvent] = []
        
        // Add selected events (curated)
        if let selected = selected {
            combined.append(contentsOf: selected)
        }
        
        // Add general events
        if let events = events {
            combined.append(contentsOf: events)
        }
        
        // Sort by year descending (most recent first)
        return combined.sorted { $0.year > $1.year }
    }
}

/// Represents a single event that happened on this day
struct OnThisDayEvent: Codable, Identifiable, Hashable {
    let id = UUID()
    let year: Int
    let text: String
    let pages: [WikipediaPage]
    
    enum CodingKeys: String, CodingKey {
        case year
        case text
        case pages
    }
}

/// Represents a Wikipedia page associated with an event
struct WikipediaPage: Codable, Identifiable, Hashable {
    let id = UUID()
    let title: String
    let thumbnail: Thumbnail?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case thumbnail
        case description
    }
}

// MARK: - Cached On This Day Data

/// Cached version of On This Day data for offline support
struct CachedOnThisDayData: Codable {
    let date: String // Format: "MM-DD"
    let language: String
    let events: [CachedOnThisDayEvent]
    let cachedAt: Date
    
    var isExpired: Bool {
        // Cache expires after 24 hours
        return Date().timeIntervalSince(cachedAt) > 24 * 60 * 60
    }
}

/// Cached version of an event
struct CachedOnThisDayEvent: Codable {
    let year: Int
    let text: String
    let pages: [CachedWikipediaPage]
}

/// Cached version of a Wikipedia page
struct CachedWikipediaPage: Codable {
    let title: String
    let thumbnailSource: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let description: String?
    
    func toWikipediaPage() -> WikipediaPage {
        var thumbnail: Thumbnail?
        if let source = thumbnailSource, let width = thumbnailWidth, let height = thumbnailHeight {
            thumbnail = Thumbnail(source: source, width: width, height: height)
        }
        return WikipediaPage(title: title, thumbnail: thumbnail, description: description)
    }
}

// MARK: - Extensions for Conversion

extension OnThisDayEvent {
    func toCached() -> CachedOnThisDayEvent {
        return CachedOnThisDayEvent(
            year: year,
            text: text,
            pages: pages.map { $0.toCached() }
        )
    }
}

extension WikipediaPage {
    func toCached() -> CachedWikipediaPage {
        return CachedWikipediaPage(
            title: title,
            thumbnailSource: thumbnail?.source,
            thumbnailWidth: thumbnail?.width,
            thumbnailHeight: thumbnail?.height,
            description: description
        )
    }
}

extension CachedOnThisDayData {
    func toOnThisDayResponse() -> OnThisDayResponse {
        let convertedEvents = events.map { event in
            OnThisDayEvent(
                year: event.year,
                text: event.text,
                pages: event.pages.map { $0.toWikipediaPage() }
            )
        }
        return OnThisDayResponse(
            selected: nil,
            events: convertedEvents,
            births: nil,
            deaths: nil,
            holidays: nil
        )
    }
}
