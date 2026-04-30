import Foundation

/// Серверная конфигурация — позволяет менять поведение приложения без релиза.
/// Загружается с `/api/app-config/?platform=ios&version=<short>` при старте.
struct AppConfig: Codable {

    // MARK: - Версионирование (force-update / soft-update)
    let minSupportedVersion: String?
    let recommendedVersion: String?
    let appStoreUrl: String?

    // MARK: - Maintenance
    let maintenance: Maintenance?

    // MARK: - Бренды и сети
    /// Цвета сетей в hex (#RRGGBB) — overide локальной BrandPalette.storeColor.
    /// Ключ — chain_slug.
    let chainColors: [String: String]?
    /// Популярные бренды на экране Каталога. Если пусто — используется встроенный список.
    let popularBrands: [PopularBrand]?

    // MARK: - Промо
    let homeBanners: [Banner]?

    // MARK: - Feature flags
    /// Дикт булевых флагов. Ключи стабильны: см. FeatureFlag.
    let features: [String: Bool]?

    // MARK: - Тексты onboarding/копи
    let copy: [String: String]?

    // MARK: - Версия конфига (для логов и кеш-сравнений)
    let configVersion: Int?

    struct Maintenance: Codable {
        let enabled: Bool
        let message: String?
        let endsAt: String?  // ISO8601
    }

    struct PopularBrand: Codable, Hashable {
        let name: String
        let emoji: String?
        /// URL логотипа — если backend пришлёт лого, эмоджи можно не показывать.
        let logoUrl: String?
    }

    struct Banner: Codable, Identifiable {
        var id: String { slug }
        let slug: String
        let title: String
        let subtitle: String?
        let actionUrl: String?
        let imageUrl: String?
        let backgroundColor: String?
    }

    /// Стабильные ключи feature-флагов. Хранение в `features: [String: Bool]`.
    /// rawValue — snake_case, потому что JSONDecoder.convertFromSnakeCase не
    /// трогает ключи словарей. Бэкенд шлёт `{"store_basket_chart": true}` →
    /// в `features` оно так и остаётся.
    enum FeatureFlag: String {
        case storeBasketChart  = "store_basket_chart"
        case priceHistoryChart = "price_history_chart"
        case discountsTab      = "discounts_tab"
        case widgetSync        = "widget_sync"
        case barcodeScanner    = "barcode_scanner"
        case priceAlerts       = "price_alerts"
        case cartTransfer      = "cart_transfer"
    }
}

extension AppConfig {
    /// Дефолтный конфиг — используется когда сеть недоступна и кэша нет.
    /// Все фичи включены, версионных ограничений нет.
    static let fallback = AppConfig(
        minSupportedVersion: nil,
        recommendedVersion: nil,
        appStoreUrl: nil,
        maintenance: nil,
        chainColors: nil,
        popularBrands: nil,
        homeBanners: nil,
        features: nil,
        copy: nil,
        configVersion: 0
    )

    /// Проверка флага. Если конфига нет — возвращаем дефолт (по умолчанию true для всех фич).
    func isEnabled(_ flag: FeatureFlag, default defaultValue: Bool = true) -> Bool {
        features?[flag.rawValue] ?? defaultValue
    }

    /// Текст по ключу с fallback.
    func text(_ key: String, default defaultValue: String) -> String {
        copy?[key] ?? defaultValue
    }
}

// MARK: - Сравнение версий вида "1.2.3"

extension AppConfig {
    /// Текущее состояние версии относительно конфига.
    enum VersionGate {
        case ok                  // версия актуальна
        case softUpdate          // желательно обновиться (recommendedVersion > current)
        case forceUpdate         // обязательно обновиться (minSupportedVersion > current)
        case maintenance(String) // приложение в режиме обслуживания
    }

    /// Сравнить текущую версию приложения с минимально-/рекомендуемо-поддерживаемой.
    func versionGate(currentVersion: String) -> VersionGate {
        if let m = maintenance, m.enabled {
            return .maintenance(m.message ?? "Приложение временно недоступно. Скоро вернёмся.")
        }
        if let min = minSupportedVersion, compareVersions(currentVersion, min) == .orderedAscending {
            return .forceUpdate
        }
        if let rec = recommendedVersion, compareVersions(currentVersion, rec) == .orderedAscending {
            return .softUpdate
        }
        return .ok
    }

    /// Лексикографическое сравнение версий по частям (1.10.0 > 1.9.5).
    private func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let maxLen = max(aParts.count, bParts.count)
        for i in 0..<maxLen {
            let ai = i < aParts.count ? aParts[i] : 0
            let bi = i < bParts.count ? bParts[i] : 0
            if ai < bi { return .orderedAscending }
            if ai > bi { return .orderedDescending }
        }
        return .orderedSame
    }
}
