import Foundation

struct City: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
}

struct CitiesResponse: Codable {
    let cities: [City]
}

struct Chain: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let source: String
    let logo: String?

    var logoURL: URL? {
        guard let logo else { return nil }
        if logo.hasPrefix("http") { return URL(string: logo) }
        if logo.hasPrefix("/") { return URL(string: "https://backend.minprice.kz\(logo)") }
        return URL(string: "https://backend.minprice.kz/media/\(logo)")
    }
}

struct ChainsResponse: Codable {
    let chains: [Chain]
}

struct Category: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let emoji: String?
    let level: Int
    let priority: Int
    let children: [Category]?
}

struct CategoriesResponse: Codable {
    let categories: [Category]
}
