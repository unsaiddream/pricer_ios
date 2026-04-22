import Foundation
import WidgetKit

struct WidgetStoreData: Codable {
    let name: String
    let price: Double
    let source: String?
    let inStock: Bool
}

struct WidgetProductData: Codable {
    let id: String
    let title: String
    let brand: String?
    let minPrice: Double
    let maxPrice: Double
    let prevMinPrice: Double?
    let storeSource: String?
    let imageUrl: String?
    let stores: [WidgetStoreData]
}

enum WidgetDataStore {
    static let suiteName = "group.kz.minprice.shared"

    static func syncFavorites(_ products: [Product]) {
        let mapped: [WidgetProductData] = products.prefix(6).map { p in
            let cheapest = p.cheapestStore
            let fallbackStore = p.stores?.min(by: { $0.price < $1.price })
            let bestSource = cheapest?.storeSource ?? fallbackStore?.storeSource

            let widgetStores: [WidgetStoreData] = (p.stores ?? [])
                .filter { $0.inStock }
                .sorted { $0.price < $1.price }
                .prefix(5)
                .map { s in
                    WidgetStoreData(
                        name: s.chainName,
                        price: s.price,
                        source: s.storeSource,
                        inStock: s.inStock
                    )
                }

            return WidgetProductData(
                id: p.uuid,
                title: p.title,
                brand: p.brand,
                minPrice: p.cheapestPrice ?? p.minPrice ?? 0,
                maxPrice: p.maxPrice ?? p.cheapestPrice ?? p.minPrice ?? 0,
                prevMinPrice: cheapest?.previousPrice ?? fallbackStore?.previousPrice,
                storeSource: bestSource,
                imageUrl: p.imageUrl,
                stores: widgetStores
            )
        }
        let ud = UserDefaults(suiteName: suiteName)
        ud?.set(try? JSONEncoder().encode(mapped), forKey: "widget_favorites")
        WidgetCenter.shared.reloadTimelines(ofKind: "kz.minprice.favorites")
        WidgetCenter.shared.reloadTimelines(ofKind: "kz.minprice.pricedrop")
    }

    static func syncCart(count: Int, total: Double) {
        let ud = UserDefaults(suiteName: suiteName)
        ud?.set(count, forKey: "widget_cart_count")
        ud?.set(total, forKey: "widget_cart_total")
        WidgetCenter.shared.reloadTimelines(ofKind: "kz.minprice.cart")
    }
}
