import Foundation

struct SearchResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let thumbnail: Thumbnail?
    let pageId: Int?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, url, thumbnail, pageId, imageURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        url = try container.decode(String.self, forKey: .url)
        thumbnail = try container.decodeIfPresent(Thumbnail.self, forKey: .thumbnail)
        pageId = try container.decodeIfPresent(Int.self, forKey: .pageId)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
    }
    
    init(title: String, description: String, url: String, thumbnail: Thumbnail? = nil, pageId: Int? = nil, imageURL: String? = nil) {
        self.title = title
        self.description = description
        self.url = url
        self.thumbnail = thumbnail
        self.pageId = pageId
        self.imageURL = imageURL
    }
    
    var wikipediaArticle: WikipediaArticle {
        let finalImageURL = imageURL ?? thumbnail?.source
        let finalDescription = description.isEmpty ? "No description available" : description
        let finalPageId = pageId ?? Int.random(in: 1000...9999)
        
        // Debug logging
        print("🔍 SearchResult -> WikipediaArticle conversion:")
        print("   Title: \(title)")
        print("   ImageURL: \(imageURL ?? "nil")")
        print("   Thumbnail source: \(thumbnail?.source ?? "nil")")
        print("   Final ImageURL: \(finalImageURL ?? "nil")")
        
        return WikipediaArticle(
            title: title,
            extract: finalDescription,
            pageId: finalPageId,
            imageURL: finalImageURL,
            fullURL: url
        )
    }
    
    var hasImage: Bool {
        return imageURL != nil || thumbnail?.source != nil
    }
    
    var displayImageURL: String? {
        return imageURL ?? thumbnail?.source
    }
}

