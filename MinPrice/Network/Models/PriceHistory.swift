import Foundation

struct PricePoint: Codable, Identifiable {
    var id: String { datetime }
    let date: String
    let datetime: String
    let price: Double
    let inStock: Bool

    var parsedDate: Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: datetime) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: datetime)
    }
}

struct StorePriceHistory: Codable, Identifiable {
    var id: Int { storeId }
    let storeId: Int
    let storeName: String
    let chainSource: String
    let extProductId: Int
    let extProductTitle: String
    let prices: [PricePoint]
}

struct PriceHistoryResponse: Codable {
    let productUuid: String
    let productTitle: String
    let days: Int
    let stores: [StorePriceHistory]
}
