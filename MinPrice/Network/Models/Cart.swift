import Foundation

struct CartItem: Codable, Identifiable {
    let id: Int
    let product: Product
    let quantity: Int
    let addedAt: String
    let updatedAt: String

    func replacingQuantity(_ quantity: Int) -> CartItem {
        CartItem(
            id: id,
            product: product,
            quantity: quantity,
            addedAt: addedAt,
            updatedAt: updatedAt
        )
    }
}

struct Cart: Codable, Identifiable {
    let uuid: String
    var id: String { uuid }
    let name: String
    let isActive: Bool
    let items: [CartItem]
    let itemsCount: Int
    let createdAt: String
    let updatedAt: String

    func replacingItems(_ items: [CartItem]) -> Cart {
        Cart(
            uuid: uuid,
            name: name,
            isActive: isActive,
            items: items,
            itemsCount: items.reduce(0) { $0 + $1.quantity },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct CartsResponse: Codable {
    let count: Int
    let results: [Cart]
}

// MARK: - Cart summary

struct CartSummaryStoreItem: Codable {
    let product: Product
    let quantity: Int
    let storeId: Int?
    let storeName: String?
    let chainName: String?
    let chainSlug: String?
    let chainLogo: String?
    let chainSource: String?
    private let _price: FlexibleDouble
    private let _itemTotal: FlexibleDouble
    let currency: String?
    let url: String?
    let extProductId: Int?
    let extProductTitle: String?
    let extProductImage: String?

    var price: Double { _price.value ?? 0 }
    var itemTotal: Double { _itemTotal.value ?? 0 }

    enum CodingKeys: String, CodingKey {
        case product, quantity, storeId, storeName, chainName, chainSlug, chainLogo, chainSource
        case _price = "price"
        case _itemTotal = "itemTotal"
        case currency, url, extProductId, extProductTitle, extProductImage
    }
}

struct CartGroupedStore: Codable, Identifiable {
    var id: Int { storeId }
    let storeId: Int
    let storeName: String
    let chainName: String
    let chainSlug: String?
    let chainSource: String
    let chainLogo: String?
    let products: [CartSummaryStoreItem]
    private let _storeTotal: FlexibleDouble
    var storeTotal: Double { _storeTotal.value ?? 0 }

    enum CodingKeys: String, CodingKey {
        case storeId, storeName, chainName, chainSlug, chainSource, chainLogo, products
        case _storeTotal = "storeTotal"
    }
}

struct CartSummaryResponse: Codable {
    let cart: Cart
    let totalItems: Int
    let cheapestPerProduct: [CartSummaryStoreItem]
    private let _cheapestTotalPrice: FlexibleDouble
    var cheapestTotalPrice: Double { _cheapestTotalPrice.value ?? 0 }
    let groupedByStore: [CartGroupedStore]
    let unavailableProducts: [UnavailableProduct]
    let singleStoreTotals: [SingleStoreTotal]

    enum CodingKeys: String, CodingKey {
        case cart, totalItems, cheapestPerProduct
        case _cheapestTotalPrice = "cheapestTotalPrice"
        case groupedByStore, unavailableProducts, singleStoreTotals
    }
}

struct CartStateSnapshot {
    let cart: Cart
    let itemsCount: Int
    let total: Double
}

extension CartSummaryResponse {
    var hasVisibleItems: Bool {
        !cheapestPerProduct.isEmpty || !unavailableProducts.isEmpty
    }

    var cartStateSnapshot: CartStateSnapshot {
        cartStateSnapshot(quantityOverrides: [:])
    }

    func cartStateSnapshot(quantityOverrides: [String: Int]) -> CartStateSnapshot {
        let computedTotal = cheapestPerProduct.reduce(0) { total, item in
            let quantity = quantityOverrides[item.product.uuid] ?? item.quantity
            return total + item.price * Double(quantity)
        }
        let availableCount = cheapestPerProduct.reduce(0) { total, item in
            total + (quantityOverrides[item.product.uuid] ?? item.quantity)
        }
        let unavailableCount = unavailableProducts.reduce(0) { total, item in
            total + (quantityOverrides[item.product.uuid] ?? item.quantity)
        }

        return CartStateSnapshot(
            cart: cart.applyingQuantityOverrides(quantityOverrides),
            itemsCount: availableCount + unavailableCount,
            total: quantityOverrides.isEmpty && cheapestTotalPrice > 0 ? cheapestTotalPrice : computedTotal
        )
    }
}

extension Cart {
    func applyingQuantityOverrides(_ overrides: [String: Int]) -> Cart {
        guard !overrides.isEmpty else { return self }
        let updatedItems = items.compactMap { item -> CartItem? in
            guard let quantity = overrides[item.product.uuid] else { return item }
            guard quantity > 0 else { return nil }
            return item.replacingQuantity(quantity)
        }
        return replacingItems(updatedItems)
    }
}

struct UnavailableProduct: Codable {
    let product: Product
    let quantity: Int
    let reason: String
}

struct SingleStoreTotal: Codable, Identifiable {
    var id: Int { storeId }
    let storeId: Int
    let storeName: String
    let chainName: String
    let chainSlug: String?
    let chainSource: String
    let chainLogo: String?
    private let _totalPrice: FlexibleDouble
    var totalPrice: Double { _totalPrice.value ?? 0 }
    let availableCount: Int
    let totalCount: Int
    let products: [CartSummaryStoreItem]

    enum CodingKeys: String, CodingKey {
        case storeId, storeName, chainName, chainSlug, chainSource, chainLogo
        case _totalPrice = "totalPrice"
        case availableCount, totalCount, products
    }
}

// MARK: - Request bodies

struct AddItemBody: Encodable {
    let productUuid: String
    let quantity: Int
}

struct RemoveItemBody: Encodable {
    let productUuid: String
}

struct UpdateQuantityBody: Encodable {
    let productUuid: String
    let quantity: Int
}

struct QuickAddResponse: Codable {
    let cartUuid: String
    let itemsCount: Int
    // item намеренно не декодируем — вложенный Product нестабилен
}

// MARK: - Cart transfer (deeplink to store)

struct CartTransferItem: Encodable {
    let extId: String
    let quantity: Int
    let title: String?
    let url: String?
}

struct CartTransferBody: Encodable {
    let chainSource: String
    let chainSlug: String?  // нужен чтобы Wolt-deeplink знал какая сеть (Small/Galmart/Toimart)
    let items: [CartTransferItem]
    let cityId: Int
}

struct CartTransferResponse: Codable {
    let chainSource: String
    let success: Bool
    let cartUrl: String?
    let itemsCount: Int
    let error: String?
}
