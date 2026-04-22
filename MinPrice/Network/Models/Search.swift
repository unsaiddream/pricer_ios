import Foundation

struct SearchResponse: Codable {
    let hits: [Product]
    let nbHits: Int
    let page: Int
    let nbPages: Int
    let hitsPerPage: Int
    let query: String
}
