import Foundation
import WidgetKit

struct WidgetStoreData: Codable {
    let name: String
    let price: Double
    let source: String?
    let slug: String?       // chain_slug — отличает Galmart/Toimart/Small (общий source = wolt)
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
    let storeSlug: String?  // chain_slug лучшего магазина
    let imageUrl: String?
    let stores: [WidgetStoreData]
}

enum WidgetDataStore {
    static let suiteName = "group.kz.minprice.shared"

    static func syncFavorites(_ products: [Product]) {
        let mapped: [WidgetProductData] = products.prefix(6).map { p in
            // priceRange.stores — детальные данные (с ProductView), stores — из поиска
            let rangeStores = p.priceRange?.stores ?? []
            let searchStores = p.stores ?? []

            let widgetStores: [WidgetStoreData]
            if !rangeStores.isEmpty {
                widgetStores = rangeStores
                    .sorted { $0.price < $1.price }
                    .prefix(5)
                    .map { s in
                        WidgetStoreData(name: s.chainName, price: s.price,
                                        source: s.storeSource, slug: s.chainSlug, inStock: s.inStock)
                    }
            } else {
                widgetStores = searchStores
                    .sorted { $0.price < $1.price }
                    .prefix(5)
                    .map { s in
                        WidgetStoreData(name: s.chainName, price: s.price,
                                        source: s.storeSource, slug: s.chainSlug, inStock: s.inStock)
                    }
            }

            let bestRange = rangeStores.min(by: { $0.price < $1.price })
            let bestSearch = searchStores.min(by: { $0.price < $1.price })
            let bestSource = bestRange?.storeSource ?? bestSearch?.storeSource
            let bestSlug   = bestRange?.chainSlug   ?? bestSearch?.chainSlug
            let prevPrice  = bestRange?.previousPrice ?? bestSearch?.previousPrice

            return WidgetProductData(
                id: p.uuid,
                title: p.title,
                brand: p.brand,
                minPrice: p.cheapestPrice ?? p.minPrice ?? 0,
                maxPrice: p.maxPrice ?? p.cheapestPrice ?? p.minPrice ?? 0,
                prevMinPrice: prevPrice,
                storeSource: bestSource,
                storeSlug: bestSlug,
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
