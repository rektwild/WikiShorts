import Foundation

struct WikipediaArticle: Identifiable, Codable {
    let id = UUID()
    let title: String
    let extract: String
    let pageId: Int
    let imageURL: String?
    let fullURL: String
    
    enum CodingKeys: String, CodingKey {
        case title, extract
        case pageId = "pageid"
        case imageURL = "thumbnail"
        case fullURL = "fullurl"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        extract = try container.decode(String.self, forKey: .extract)
        pageId = try container.decode(Int.self, forKey: .pageId)
        fullURL = try container.decode(String.self, forKey: .fullURL)
        
        if let thumbnail = try? container.decode(Thumbnail.self, forKey: .imageURL) {
            imageURL = thumbnail.source
        } else {
            imageURL = nil
        }
    }
    
    init(title: String, extract: String, pageId: Int, imageURL: String? = nil, fullURL: String) {
        self.title = title
        self.extract = extract
        self.pageId = pageId
        self.imageURL = imageURL
        self.fullURL = fullURL
    }
}

struct Thumbnail: Codable {
    let source: String
    let width: Int
    let height: Int
}

struct WikipediaResponse: Codable {
    let query: Query
}

struct Query: Codable {
    let pages: [String: Page]
}

struct Page: Codable {
    let pageid: Int
    let title: String
    let extract: String
    let thumbnail: Thumbnail?
    let fullurl: String
}