import Foundation

struct StorePrice: Codable, Identifiable {
    var id: Int { storeId }
    let storeId: Int
    let storeName: String
    let storeSource: String
    let chainId: Int
    let chainName: String
    let chainSlug: String?  // уникальный идентификатор сети (galmart/toimart/small под одним wolt)
    let chainLogo: String?
    let price: Double
    let previousPrice: Double?
    let currency: String
    let inStock: Bool
    let url: String?
    let extProductId: Int?
    let extProductTitle: String?
    let extProductImage: String?
    let extProductMeasureUnit: String?
    let extProductMeasureUnitQty: FlexibleDouble?
    let extProductPackCount: Int?
    let similarityCoef: Double?
    let aiCoef: Double?

    var discountPercent: Double? {
        guard let prev = previousPrice, prev > 0, price < prev else { return nil }
        return ((prev - price) / prev) * 100
    }

    var logoURL: URL? {
        guard let logo = chainLogo else { return nil }
        if logo.hasPrefix("http") { return URL(string: logo) }
        if logo.hasPrefix("/") { return URL(string: "https://backend.minprice.kz\(logo)") }
        return URL(string: "https://backend.minprice.kz/media/\(logo)")
    }
}

struct Product: Codable, Identifiable {
    let id: Int
    let uuid: String
    let title: String
    let brand: String?
    let imageUrl: String?
    let measureUnit: String?
    let measureUnitKind: String?
    let measureUnitQty: FlexibleDouble?
    let packCount: Int?
    private let _minPrice: FlexibleDouble?
    private let _maxPrice: FlexibleDouble?
    let isActive: Bool
    let linkedStoresCount: Int?
    let stores: [StorePrice]?

    // Detail-only fields
    let description: String?
    let priceRange: PriceRange?

    var minPrice: Double? { _minPrice?.value }
    var maxPrice: Double? { _maxPrice?.value }

    enum CodingKeys: String, CodingKey {
        case id, uuid, title, brand, imageUrl, measureUnit, measureUnitKind, measureUnitQty, packCount, isActive, linkedStoresCount, stores, description, priceRange
        case _minPrice = "minPrice"
        case _maxPrice = "maxPrice"
    }

    var coverURL: URL? {
        guard let img = imageUrl else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "https://backend.minprice.kz/media/\(img)")
    }

    var cheapestPrice: Double? {
        if let min = priceRange?.min { return min }
        return minPrice
    }

    var cheapestStore: PriceRangeStore? {
        priceRange?.stores.first(where: { $0.price == priceRange?.min })
    }
}

struct PriceRange: Codable {
    let min: Double
    let max: Double
    let avg: Double
    let savings: Double?
    let savingsPercent: Double?
    let stores: [PriceRangeStore]
}

struct PriceRangeStore: Codable {
    let storeName: String
    let storeSource: String
    let chainId: Int
    let chainName: String
    let chainSlug: String?
    let chainLogo: String?
    let price: Double
    let previousPrice: Double?
    let discountAmount: Double?
    let currency: String
    let inStock: Bool
    let url: String?
    let extProductId: Int?
    let extProductTitle: String?
    let extProductImage: String?

    var logoURL: URL? {
        guard let logo = chainLogo else { return nil }
        if logo.hasPrefix("http") { return URL(string: logo) }
        if logo.hasPrefix("/") { return URL(string: "https://backend.minprice.kz\(logo)") }
        return URL(string: "https://backend.minprice.kz/media/\(logo)")
    }
}

// MARK: - List responses

struct ProductsResponse: Codable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [Product]
}

struct BestDealsResponse: Codable {
    let deals: [Product]
}

struct PriceDropsResponse: Codable {
    let results: [Product]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
}

struct PriceIncreasesResponse: Codable {
    let results: [Product]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
}

struct DiscountsResponse: Codable {
    let results: [Product]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
}
