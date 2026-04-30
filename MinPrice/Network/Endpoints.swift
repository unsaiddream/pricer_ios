import Foundation

enum Endpoint {
    // MARK: - Reference
    static func cities() -> String { "/cities/" }
    static func chains() -> String { "/chains/" }
    static func categories() -> String { "/categories/" }

    // MARK: - Home
    static func bestDeals() -> String { "/best-deals/" }
    // /price-drops/ и /price-increases/ убраны на бэке (см. main pricer репо).
    // Используем /discounts/ для секции "Снижение цен" на главной.
    /// Готовый агрегат для главного графика-корзины. Бэк считает SQL+Python,
    /// клиент только рендерит. См. docs/STORE_BASKET_CONTRACT.md.
    static func storeBasket() -> String { "/home/basket/" }

    // MARK: - Products
    static func products() -> String { "/products/" }
    static func product(_ uuid: String) -> String { "/products/\(uuid)/" }
    static func priceHistory(_ uuid: String) -> String { "/products/\(uuid)/price-history/" }

    // MARK: - Search
    static func search() -> String { "/search/" }

    // MARK: - Discounts
    static func discounts() -> String { "/discounts/" }

    // MARK: - Cart
    static func carts() -> String { "/carts/" }
    static func cart(_ uuid: String) -> String { "/carts/\(uuid)/" }
    static func cartSummary(_ uuid: String) -> String { "/carts/\(uuid)/summary/" }
    static func cartAddItem(_ uuid: String) -> String { "/carts/\(uuid)/add_item/" }
    static func cartRemoveItem(_ uuid: String) -> String { "/carts/\(uuid)/remove_item/" }
    static func cartUpdateQuantity(_ uuid: String) -> String { "/carts/\(uuid)/update_quantity/" }
    static func cartQuickAdd() -> String { "/cart/add/" }
    static func cartTransfer() -> String { "/cart/transfer/" }
}
