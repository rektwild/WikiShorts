import Foundation

struct SearchResult: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let thumbnail: Thumbnail?
    
    var wikipediaArticle: WikipediaArticle {
        return WikipediaArticle(
            title: title,
            extract: description,
            pageId: Int.random(in: 1000...9999),
            imageURL: nil,
            fullURL: url
        )
    }
}

