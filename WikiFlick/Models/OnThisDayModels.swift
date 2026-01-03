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
    let events: [OnThisDayEvent]
    
    enum CodingKeys: String, CodingKey {
        case events = "events"
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
        return OnThisDayResponse(
            events: events.map { event in
                OnThisDayEvent(
                    year: event.year,
                    text: event.text,
                    pages: event.pages.map { $0.toWikipediaPage() }
                )
            }
        )
    }
}
