import WidgetKit
import SwiftUI
import UIKit

// MARK: ═══════════════════════════════════
// MARK: DESIGN TOKENS
// MARK: ═══════════════════════════════════

// Палитра виджета — синхронизирована 1:1 с AppTheme основного приложения.
// При смене бренд-цветов правим обе таблицы: здесь и в Shared/Extensions/AppTheme.swift.
private extension Color {
    static let wPrimary     = Color(red: 0.07, green: 0.71, blue: 0.84)  // appPrimary
    static let wPrimaryDeep = Color(red: 0.05, green: 0.55, blue: 0.70)  // appPrimaryDeep
    static let wPrimarySoft = Color(red: 0.45, green: 0.85, blue: 0.95)  // appPrimaryLight
    static let wGreen       = Color(red: 0.14, green: 0.72, blue: 0.50)  // savingsGreen
    static let wGreenSoft   = Color(red: 0.40, green: 0.85, blue: 0.65)  // savingsGreenSoft
    static let wGreenDeep   = Color(red: 0.05, green: 0.50, blue: 0.30)  // savingsGreenDeep
    static let wRed         = Color(red: 0.88, green: 0.38, blue: 0.45)  // discountRed
    static let wRedSoft     = Color(red: 0.95, green: 0.50, blue: 0.55)  // softer than discountRed
    static let wAmber       = Color(red: 0.96, green: 0.62, blue: 0.16)  // warningAmber
    static let wInk         = Color(red: 0.05, green: 0.10, blue: 0.16)
}

/// Идентификация сети — по chain_slug (приоритет) или source (fallback).
/// Small/Galmart/Toimart имеют одинаковый source = "wolt", поэтому slug нужен
/// для разделения этих 3 сетей.
private func resolveSlug(slug: String?, source: String?) -> String? {
    if let s = slug, !s.isEmpty { return s.lowercased() }
    switch source?.lowercased() {
    case "mgo":        return "mgo"
    case "arbuz":      return "arbuz"
    case "airbafresh": return "airbafresh"
    case "wolt":       return "small"   // legacy дефолт
    default:           return source?.lowercased()
    }
}

private func storeLabel(slug: String?, source: String?) -> String {
    switch resolveSlug(slug: slug, source: source) {
    case "mgo":        return "Magnum"
    case "arbuz":      return "Arbuz"
    case "airbafresh": return "Airba"
    case "small":      return "Small"
    case "galmart":    return "Galmart"
    case "toimart":    return "Toimart"
    default:           return source ?? "—"
    }
}

private func storeColor(slug: String?, source: String?) -> Color {
    switch resolveSlug(slug: slug, source: source) {
    case "mgo":        return Color(red: 0.95, green: 0.30, blue: 0.30)
    case "arbuz":      return Color(red: 1.00, green: 0.55, blue: 0.20)
    case "airbafresh": return Color(red: 0.30, green: 0.65, blue: 1.00)
    case "small":      return Color(red: 0.70, green: 0.45, blue: 1.00)
    case "galmart":    return Color(red: 0.20, green: 0.78, blue: 0.55)
    case "toimart":    return Color(red: 1.00, green: 0.42, blue: 0.65)
    default:           return .wPrimary
    }
}

private func storeAsset(slug: String?, source: String?) -> String? {
    switch resolveSlug(slug: slug, source: source) {
    case "mgo":        return "store_magnum"
    case "arbuz":      return "store_arbuz"
    case "airbafresh": return "store_airba_fresh"
    case "small":      return "store_small"
    // galmart/toimart — без локального ассета; в виджете рисуем цветной круг с буквой
    default:           return nil
    }
}

// Старые сигнатуры — fallback (если в данных только source).
private func storeLabel(_ source: String?) -> String { storeLabel(slug: nil, source: source) }
private func storeColor(_ source: String?) -> Color  { storeColor(slug: nil, source: source) }
private func storeAsset(_ source: String?) -> String? { storeAsset(slug: nil, source: source) }

private func fmt(_ v: Double) -> String {
    let n = NumberFormatter()
    n.numberStyle = .decimal
    n.groupingSeparator = " "
    n.maximumFractionDigits = 0
    return "\(n.string(from: NSNumber(value: v)) ?? "\(Int(v))") ₸"
}

private func priceFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}

private func productURL(_ id: String) -> URL {
    URL(string: "minprice://product/\(id)")!
}

// MARK: ═══════════════════════════════════
// MARK: MODELS
// MARK: ═══════════════════════════════════

struct WidgetStore: Codable, Hashable {
    let name: String
    let price: Double
    let source: String?
    let slug: String?
    let inStock: Bool
}

struct WidgetProduct: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let brand: String?
    let minPrice: Double
    let maxPrice: Double
    let prevMinPrice: Double?
    let storeSource: String?
    let storeSlug: String?
    let imageUrl: String?
    let stores: [WidgetStore]

    init(id: String, title: String, brand: String?, minPrice: Double, maxPrice: Double,
         prevMinPrice: Double?, storeSource: String?, storeSlug: String?, imageUrl: String?, stores: [WidgetStore]) {
        self.id = id; self.title = title; self.brand = brand
        self.minPrice = minPrice; self.maxPrice = maxPrice
        self.prevMinPrice = prevMinPrice; self.storeSource = storeSource; self.storeSlug = storeSlug
        self.imageUrl = imageUrl; self.stores = stores
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try  c.decode(String.self,         forKey: .id)
        title        = try  c.decode(String.self,         forKey: .title)
        brand        = try? c.decode(String.self,         forKey: .brand)
        minPrice     = try  c.decode(Double.self,         forKey: .minPrice)
        maxPrice     = try  c.decode(Double.self,         forKey: .maxPrice)
        prevMinPrice = try? c.decode(Double.self,         forKey: .prevMinPrice)
        storeSource  = try? c.decode(String.self,         forKey: .storeSource)
        storeSlug    = try? c.decode(String.self,         forKey: .storeSlug)
        imageUrl     = try? c.decode(String.self,         forKey: .imageUrl)
        stores       = (try? c.decode([WidgetStore].self, forKey: .stores)) ?? []
    }

    var imageURL: URL? {
        guard let img = imageUrl, !img.isEmpty else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "https://backend.minprice.kz/media/\(img)")
    }

    var dropPercent: Int? {
        guard let prev = prevMinPrice, prev > minPrice, prev > 0 else { return nil }
        let p = Int(((prev - minPrice) / prev) * 100)
        return p > 0 ? p : nil
    }

    var savings: Double? {
        guard let prev = prevMinPrice, prev > minPrice else { return nil }
        return prev - minPrice
    }

    // Разница между дешёвым и дорогим магазином — показывает выгоду выбора
    var spread: Double? {
        let prices = stores.filter(\.inStock).map(\.price)
        guard let min = prices.min(), let max = prices.max(), max > min else { return nil }
        return max - min
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let products: [WidgetProduct]
    let images: [String: UIImage]
    let cartCount: Int
    let cartTotal: Double

    var bestDrop: WidgetProduct? {
        products.compactMap { p -> (WidgetProduct, Int)? in
            guard let d = p.dropPercent else { return nil }
            return (p, d)
        }.max(by: { $0.1 < $1.1 })?.0
    }

    var totalSavings: Double {
        products.compactMap(\.savings).reduce(0, +)
    }

    var dropsCount: Int {
        products.filter { $0.dropPercent != nil }.count
    }
}

// MARK: ═══════════════════════════════════
// MARK: MOCK
// MARK: ═══════════════════════════════════

private let mockStores: [WidgetStore] = [
    WidgetStore(name: "Magnum",      price: 649, source: "mgo", slug: nil, inStock: true),
    WidgetStore(name: "Arbuz",       price: 720, source: "arbuz", slug: nil, inStock: true),
    WidgetStore(name: "Airba Fresh", price: 780, source: "airbafresh", slug: nil, inStock: true),
]

private let mockProducts: [WidgetProduct] = [
    WidgetProduct(id: "1", title: "Молоко Простоквашино 3.2% 1л",
                  brand: "Простоквашино", minPrice: 649, maxPrice: 780,
                  prevMinPrice: 820, storeSource: "mgo", storeSlug: nil, imageUrl: nil, stores: mockStores),
    WidgetProduct(id: "2", title: "Хлеб белый нарезной 500г",
                  brand: nil, minPrice: 320, maxPrice: 390,
                  prevMinPrice: nil, storeSource: "arbuz", storeSlug: nil, imageUrl: nil,
                  stores: [
                    WidgetStore(name: "Arbuz", price: 320, source: "arbuz", slug: nil, inStock: true),
                    WidgetStore(name: "Small", price: 355, source: "small", slug: nil, inStock: true),
                    WidgetStore(name: "Magnum", price: 390, source: "mgo", slug: nil, inStock: true),
                  ]),
    WidgetProduct(id: "3", title: "Яйца куриные С1 10шт",
                  brand: nil, minPrice: 890, maxPrice: 1100,
                  prevMinPrice: 1100, storeSource: "airbafresh", storeSlug: nil, imageUrl: nil,
                  stores: [
                    WidgetStore(name: "Airba", price: 890, source: "airbafresh", slug: nil, inStock: true),
                    WidgetStore(name: "Magnum", price: 960, source: "mgo", slug: nil, inStock: true),
                  ]),
    WidgetProduct(id: "4", title: "Масло сливочное 82.5% 180г",
                  brand: nil, minPrice: 1250, maxPrice: 1450,
                  prevMinPrice: 1380, storeSource: "mgo", storeSlug: nil, imageUrl: nil,
                  stores: [
                    WidgetStore(name: "Magnum", price: 1250, source: "mgo", slug: nil, inStock: true),
                    WidgetStore(name: "Arbuz", price: 1450, source: "arbuz", slug: nil, inStock: true),
                  ]),
]

// MARK: ═══════════════════════════════════
// MARK: PROVIDER
// MARK: ═══════════════════════════════════

struct MinPriceProvider: TimelineProvider {
    private let suite = "group.kz.minprice.shared"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), products: mockProducts, images: [:], cartCount: 5, cartTotal: 12_400)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            Task { completion(await loadEntry()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> WidgetEntry {
        let ud = UserDefaults(suiteName: suite)
        var products: [WidgetProduct] = []
        if let data = ud?.data(forKey: "widget_favorites"),
           let decoded = try? JSONDecoder().decode([WidgetProduct].self, from: data) {
            products = decoded
        }
        let images = await fetchImages(for: products)
        return WidgetEntry(
            date: Date(),
            products: products,
            images: images,
            cartCount: ud?.integer(forKey: "widget_cart_count") ?? 0,
            cartTotal: ud?.double(forKey: "widget_cart_total") ?? 0
        )
    }

    private func fetchImages(for products: [WidgetProduct]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for product in products {
                guard let url = product.imageURL else { continue }
                group.addTask {
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let img = UIImage(data: data) else { return (product.id, nil) }
                    return (product.id, img)
                }
            }
            var result: [String: UIImage] = [:]
            for await (id, img) in group { if let img { result[id] = img } }
            return result
        }
    }
}

// MARK: ═══════════════════════════════════
// MARK: PRIMITIVES
// MARK: ═══════════════════════════════════

private struct LogoMark: View {
    var size: CGFloat = 18
    var glow: Bool = false
    var glowColor: Color = .wPrimary

    var body: some View {
        ZStack {
            if glow {
                Circle()
                    .fill(glowColor.opacity(0.45))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.5)
            }
            if let logo = UIImage(named: "AppLogo") {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.wPrimarySoft, .wPrimary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Text("m")
                        .font(.system(size: size * 0.6, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: size, height: size)
            }
        }
    }
}

private struct BrandLogo: View {
    var size: CGFloat = 11
    var color: Color = .wPrimary
    var dark: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            LogoMark(size: size * 1.5, glow: dark, glowColor: color)
            Text("minprice")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .kerning(-0.3)
        }
    }
}

private struct ProductPhoto: View {
    let image: UIImage?
    var radius: CGFloat = 14
    var accent: Color = .wPrimary

    var body: some View {
        ZStack {
            // Многослойный фон — мягкий радиальный градиент
            LinearGradient(
                colors: [.white, accent.opacity(0.05)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [accent.opacity(0.10), .clear],
                center: .topLeading, startRadius: 4, endRadius: 80
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            } else {
                Image(systemName: "cube.box.fill")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(accent.opacity(0.22))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.85), accent.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
    }
}

// Bright pill for -XX% — теперь с шиммером и мягким свечением
private struct DiscountPill: View {
    let percent: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: compact ? 7 : 8, weight: .black))
            Text("\(percent)%")
                .font(.system(size: compact ? 10 : 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2.5 : 3.5)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.wRedSoft, Color.wRed],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.white.opacity(0.35), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
            .clipShape(Capsule())
        }
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
        )
        .shadow(color: Color.wRed.opacity(0.45), radius: 5, x: 0, y: 2)
    }
}

// "Экономия XXX ₸" — зелёная пилюля
private struct SavingsPill: View {
    let amount: Double
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            Text("−\(fmt(amount))")
                .font(.system(size: compact ? 10 : 11, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(Color.wGreenDeep)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 2.5 : 3.5)
        .background(
            LinearGradient(
                colors: [Color.wGreen.opacity(0.18), Color.wGreen.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(Color.wGreen.opacity(0.30), lineWidth: 0.6)
        )
    }
}

// Мини-график цен: горизонтальные полоски с относительной длиной
private struct PriceComparisonChart: View {
    let stores: [WidgetStore]

    private var minPrice: Double { stores.map(\.price).min() ?? 1 }
    private var maxPrice: Double { stores.map(\.price).max() ?? 1 }

    var body: some View {
        VStack(spacing: 5) {
            ForEach(Array(stores.prefix(3).enumerated()), id: \.offset) { _, store in
                let isMin = store.price == minPrice
                let ratio = store.price / maxPrice

                HStack(spacing: 7) {
                    if let asset = storeAsset(slug: store.slug, source: store.source) {
                        Image(asset).resizable().scaledToFit()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Circle().fill(storeColor(slug: store.slug, source: store.source)).frame(width: 10, height: 10)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(white: 0.5).opacity(0.10))
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    isMin
                                        ? LinearGradient(
                                            colors: [Color.wGreenSoft, Color.wGreen],
                                            startPoint: .leading, endPoint: .trailing
                                          )
                                        : LinearGradient(
                                            colors: [Color(white: 0.72), Color(white: 0.58)],
                                            startPoint: .leading, endPoint: .trailing
                                          )
                                )
                                .frame(width: max(14, geo.size.width * ratio), height: 6)
                                .shadow(
                                    color: isMin ? Color.wGreen.opacity(0.45) : .clear,
                                    radius: 3, x: 0, y: 1
                                )
                            if isMin {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 4, height: 4)
                                    .offset(x: max(14, geo.size.width * ratio) - 8)
                            }
                        }
                    }
                    .frame(height: 6)

                    Text(fmt(store.price))
                        .font(.system(size: 10, weight: isMin ? .heavy : .medium, design: .rounded))
                        .foregroundStyle(isMin ? Color.wGreenDeep : Color(white: 0.55))
                        .monospacedDigit()
                        .frame(width: 55, alignment: .trailing)
                }
            }
        }
    }
}

private struct EmptyFavorites: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.wPrimarySoft.opacity(0.18), Color.wPrimary.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                LogoMark(size: 28)
            }
            VStack(spacing: 2) {
                Text("Добавьте товары")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text("в избранное")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Декоративный фон с мягким бликом в углу
private struct CornerGlow: View {
    var color: Color = .wPrimary
    var corner: UnitPoint = .topTrailing

    var body: some View {
        GeometryReader { geo in
            let size = max(geo.size.width, geo.size.height)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.20), color.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: size * 0.5
                    )
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .position(
                    x: corner.x * geo.size.width,
                    y: corner.y * geo.size.height
                )
        }
        .allowsHitTesting(false)
    }
}

// MARK: ═══════════════════════════════════
// MARK: WIDGET 1 — FAVORITES
// MARK: ═══════════════════════════════════

struct FavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.favorites", provider: MinPriceProvider()) { entry in
            FavoritesWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color(UIColor.systemBackground)
                        CornerGlow(color: .wPrimary, corner: .topTrailing)
                        CornerGlow(color: .wGreenSoft.opacity(0.7), corner: .bottomLeading)
                    }
                }
        }
        .configurationDisplayName("Избранное")
        .description("Цены ваших товаров в магазинах.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct FavoritesWidgetView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if entry.products.isEmpty {
                EmptyFavorites()
            } else {
                switch family {
                case .systemSmall:  FavSmall(product: entry.products[0], images: entry.images)
                case .systemMedium: FavMedium(product: entry.products[0], images: entry.images)
                default:            FavLarge(products: Array(entry.products.prefix(4)),
                                             images: entry.images,
                                             totalSavings: entry.totalSavings,
                                             dropsCount: entry.dropsCount)
                }
            }
        }
        .widgetURL(entry.products.first.map { productURL($0.id) })
    }
}

// ── SMALL ─────────────────────────────────

private struct FavSmall: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        Link(destination: productURL(product.id)) {
            VStack(alignment: .leading, spacing: 0) {
                // Шапка: лого + бейдж скидки
                HStack(spacing: 0) {
                    LogoMark(size: 14)
                    Spacer()
                    if let pct = product.dropPercent {
                        DiscountPill(percent: pct, compact: true)
                    } else if let asset = storeAsset(slug: product.storeSlug, source: product.storeSource) {
                        Image(asset).resizable().scaledToFit()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5))
                    }
                }

                Spacer(minLength: 6)

                ProductPhoto(image: images[product.id])
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)

                Spacer(minLength: 6)

                Text(product.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(fmt(product.minPrice))
                        .font(priceFont(19))
                        .foregroundStyle(
                            product.dropPercent != nil
                                ? LinearGradient(
                                    colors: [Color.wGreenSoft, Color.wGreenDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                  )
                                : LinearGradient(
                                    colors: [Color.wPrimarySoft, Color.wPrimaryDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                  )
                        )
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        Text(fmt(prev))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(white: 0.55))
                            .strikethrough()
                    }
                }
                .padding(.top, 2)
            }
            .padding(12)
        }
    }
}

// ── MEDIUM ────────────────────────────────

private struct FavMedium: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        Link(destination: productURL(product.id)) {
            HStack(alignment: .top, spacing: 13) {
                // Левая часть — фото с дроп-баджем
                ZStack(alignment: .topLeading) {
                    ProductPhoto(image: images[product.id], radius: 16)
                        .frame(width: 118, height: 138)
                        .shadow(color: .wPrimary.opacity(0.10), radius: 10, x: 0, y: 4)
                    if let pct = product.dropPercent {
                        DiscountPill(percent: pct).padding(7)
                    }
                }

                // Правая часть
                VStack(alignment: .leading, spacing: 0) {
                    BrandLogo()

                    Spacer(minLength: 6)

                    Text(product.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)

                    Spacer(minLength: 6)

                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text(fmt(product.minPrice))
                            .font(priceFont(24))
                            .foregroundStyle(
                                product.dropPercent != nil
                                    ? LinearGradient(
                                        colors: [Color.wGreenSoft, Color.wGreenDeep],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                      )
                                    : LinearGradient(
                                        colors: [Color.wPrimarySoft, Color.wPrimaryDeep],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                      )
                            )
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        if let prev = product.prevMinPrice, prev > product.minPrice {
                            Text(fmt(prev))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(white: 0.5))
                                .strikethrough()
                        }
                    }

                    if let saved = product.savings {
                        SavingsPill(amount: saved).padding(.top, 5)
                    } else if let spread = product.spread {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 8, weight: .bold))
                            Text("разброс \(fmt(spread))")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color(white: 0.50))
                        .padding(.top, 5)
                    }

                    Spacer(minLength: 8)

                    if !product.stores.isEmpty {
                        PriceComparisonChart(stores: Array(product.stores.prefix(3)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

// ── LARGE ─────────────────────────────────

private struct FavLarge: View {
    let products: [WidgetProduct]
    let images: [String: UIImage]
    let totalSavings: Double
    let dropsCount: Int

    var body: some View {
        VStack(spacing: 0) {
            // Hero header
            HStack(alignment: .center, spacing: 10) {
                LogoMark(size: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text("minprice")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.wPrimary, Color.wPrimaryDeep],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .kerning(-0.3)
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                }

                Spacer()

                if totalSavings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text("−\(fmt(totalSavings))")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [Color.wGreenSoft, Color.wGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: Color.wGreen.opacity(0.40), radius: 5, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 11)

            VStack(spacing: 6) {
                ForEach(Array(products.enumerated()), id: \.element.id) { idx, product in
                    Link(destination: productURL(product.id)) {
                        FavLargeRow(product: product, images: images, isTop: idx == 0)
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        if dropsCount > 0 { return "\(dropsCount) скид\(dropsCount == 1 ? "ка" : "ок") · \(products.count) товар\(products.count == 1 ? "" : "ов")" }
        return "\(products.count) товар\(products.count == 1 ? "" : "ов") в избранном"
    }
}

private struct FavLargeRow: View {
    let product: WidgetProduct
    let images: [String: UIImage]
    let isTop: Bool

    var body: some View {
        HStack(spacing: 11) {
            ProductPhoto(image: images[product.id], radius: 10)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let asset = storeAsset(slug: product.storeSlug, source: product.storeSource) {
                        Image(asset).resizable().scaledToFit()
                            .frame(width: 12, height: 12)
                            .clipShape(RoundedRectangle(cornerRadius: 2.5))
                    }
                    Text(storeLabel(slug: product.storeSlug, source: product.storeSource))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.50))

                    if let pct = product.dropPercent {
                        DiscountPill(percent: pct, compact: true)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 1) {
                Text(fmt(product.minPrice))
                    .font(priceFont(15))
                    .foregroundStyle(
                        product.dropPercent != nil
                            ? LinearGradient(
                                colors: [Color.wGreenSoft, Color.wGreenDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.wPrimarySoft, Color.wPrimaryDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                              )
                    )
                    .monospacedDigit()
                if let prev = product.prevMinPrice, prev > product.minPrice {
                    Text(fmt(prev))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.5))
                        .strikethrough()
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background {
            Group {
                if isTop {
                    LinearGradient(
                        colors: [Color.wPrimary.opacity(0.13), Color.wPrimary.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    Color(white: 0.5).opacity(0.05)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isTop ? Color.wPrimary.opacity(0.30) : Color.white.opacity(0.04),
                    lineWidth: isTop ? 0.8 : 0.5
                )
        )
    }
}

// MARK: ═══════════════════════════════════
// MARK: WIDGET 2 — PRICE DROP (premium dark)
// MARK: ═══════════════════════════════════

struct PriceDropWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.pricedrop", provider: MinPriceProvider()) { entry in
            PriceDropWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        // Базовый тёмный градиент
                        LinearGradient(
                            colors: [
                                Color(red: 0.04, green: 0.10, blue: 0.16),
                                Color(red: 0.06, green: 0.18, blue: 0.26),
                                Color(red: 0.04, green: 0.22, blue: 0.20),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        // Зелёный glow в нижнем углу
                        GeometryReader { geo in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.wGreenSoft.opacity(0.45), .clear],
                                        center: .center, startRadius: 0, endRadius: 130
                                    )
                                )
                                .frame(width: 220, height: 220)
                                .offset(x: geo.size.width - 90, y: geo.size.height - 90)
                                .blur(radius: 18)
                            // Лёгкий бирюзовый акцент сверху
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.wPrimary.opacity(0.25), .clear],
                                        center: .center, startRadius: 0, endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .offset(x: -50, y: -50)
                                .blur(radius: 10)
                        }
                        // Тонкая решётка-узор
                        GeometryReader { _ in
                            Path { path in
                                for i in stride(from: 0, through: 360, by: 24) {
                                    path.move(to: CGPoint(x: CGFloat(i), y: 0))
                                    path.addLine(to: CGPoint(x: CGFloat(i), y: 360))
                                }
                            }
                            .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
                        }
                    }
                }
        }
        .configurationDisplayName("Лучшая скидка")
        .description("Самое выгодное предложение среди избранных.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PriceDropWidgetView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let product = entry.bestDrop ?? entry.products.first {
                switch family {
                case .systemMedium: DropMedium(product: product, images: entry.images)
                default:            DropSmall(product: product, images: entry.images)
                }
            } else {
                EmptyDropState()
            }
        }
        .widgetURL((entry.bestDrop ?? entry.products.first).map { productURL($0.id) })
    }
}

private struct EmptyDropState: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.wGreenSoft.opacity(0.18))
                    .frame(width: 56, height: 56)
                LogoMark(size: 28, glow: true, glowColor: .wGreenSoft)
            }
            VStack(spacing: 2) {
                Text("Нет скидок")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("в избранном")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DropSmall: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        Link(destination: productURL(product.id)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    LogoMark(size: 13, glow: true, glowColor: .wGreenSoft)
                    Text("СКИДКА ДНЯ")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .kerning(1.0)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.wGreenSoft.opacity(0.85))
                }

                Spacer(minLength: 0)

                // Большой % с эффектом неона
                if let pct = product.dropPercent {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("−")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Color.wGreenSoft.opacity(0.85))
                        Text("\(pct)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color.wGreenSoft],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.wGreenSoft.opacity(0.6), radius: 10, x: 0, y: 0)
                            .shadow(color: Color.wGreen.opacity(0.4), radius: 18, x: 0, y: 0)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Color.wGreenSoft.opacity(0.85))
                            .padding(.leading, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(product.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(fmt(product.minPrice))
                        .font(priceFont(17))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        Text(fmt(prev))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.40))
                            .strikethrough()
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct DropMedium: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        Link(destination: productURL(product.id)) {
            HStack(spacing: 14) {
                // Фото с эффектом подсветки
                ZStack {
                    // Soft green glow behind
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.wGreenSoft.opacity(0.30))
                        .blur(radius: 16)
                        .scaleEffect(1.05)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                        if let img = images[product.id] {
                            Image(uiImage: img)
                                .resizable().scaledToFit()
                                .padding(9)
                        } else {
                            Image(systemName: "cube.box.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color.wGreen.opacity(0.30))
                        }
                        // Большой бейдж скидки
                        if let pct = product.dropPercent {
                            DiscountPill(percent: pct).padding(7)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.20), lineWidth: 0.8)
                    )
                }
                .frame(width: 118, height: 138)

                // Инфо
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        LogoMark(size: 12, glow: true, glowColor: .wGreenSoft)
                        Text("СКИДКА ДНЯ")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(1.0)
                    }

                    Spacer(minLength: 6)

                    Text(product.title)
                        .font(.system(size: 13.5, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(fmt(product.minPrice))
                        .font(priceFont(28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.wGreenSoft],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.wGreenSoft.opacity(0.45), radius: 8, x: 0, y: 0)
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        HStack(spacing: 6) {
                            Text(fmt(prev))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                                .strikethrough()
                            if let saved = product.savings {
                                HStack(spacing: 2) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 8, weight: .bold))
                                    Text("−\(fmt(saved))")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                }
                                .foregroundStyle(Color.wGreenSoft)
                            }
                        }
                    }

                    Spacer(minLength: 6)

                    // Магазин + CTA
                    HStack(spacing: 6) {
                        if let asset = storeAsset(slug: product.storeSlug, source: product.storeSource) {
                            Image(asset).resizable().scaledToFit()
                                .frame(width: 16, height: 16)
                                .clipShape(RoundedRectangle(cornerRadius: 3.5))
                        }
                        Text(storeLabel(slug: product.storeSlug, source: product.storeSource))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))

                        Spacer()

                        HStack(spacing: 3) {
                            Text("открыть")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .kerning(0.3)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.08)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

// MARK: ═══════════════════════════════════
// MARK: WIDGET 3 — CART
// MARK: ═══════════════════════════════════

struct CartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.cart", provider: MinPriceProvider()) { entry in
            CartWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color(UIColor.systemBackground)
                        // Радиальный бирюзовый акцент
                        GeometryReader { geo in
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.wPrimarySoft.opacity(0.30), .clear],
                                        center: .center, startRadius: 0, endRadius: 120
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .offset(x: geo.size.width - 60, y: -60)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.wGreenSoft.opacity(0.18), .clear],
                                        center: .center, startRadius: 0, endRadius: 90
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .offset(x: -40, y: geo.size.height - 60)
                        }
                    }
                }
        }
        .configurationDisplayName("Корзина")
        .description("Сумма товаров в корзине.")
        .supportedFamilies([.systemSmall])
    }
}

private struct CartWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        Link(destination: URL(string: "minprice://cart")!) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    ZStack {
                        // Свечение под иконкой
                        Circle()
                            .fill(Color.wPrimary.opacity(0.35))
                            .frame(width: 44, height: 44)
                            .blur(radius: 8)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.wPrimarySoft, Color.wPrimary, Color.wPrimaryDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        Circle()
                            .strokeBorder(.white.opacity(0.30), lineWidth: 0.8)
                            .frame(width: 36, height: 36)
                        Image(systemName: "bag.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .wPrimaryDeep.opacity(0.5), radius: 1, x: 0, y: 1)

                        // Бейдж количества
                        if entry.cartCount > 0 {
                            Text("\(entry.cartCount)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1.5)
                                .background(
                                    LinearGradient(
                                        colors: [Color.wRedSoft, Color.wRed],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    in: Capsule()
                                )
                                .overlay(Capsule().strokeBorder(.white, lineWidth: 1.2))
                                .offset(x: 13, y: -13)
                        }
                    }
                    Spacer()
                    LogoMark(size: 18)
                }

                Spacer()

                if entry.cartCount > 0 {
                    Text("Корзина")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                        .kerning(0.8)

                    Text(fmt(entry.cartTotal))
                        .font(priceFont(26))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.wPrimarySoft, Color.wPrimaryDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .padding(.top, 1)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.wGreen)
                            .frame(width: 5, height: 5)
                            .shadow(color: Color.wGreen.opacity(0.6), radius: 3)
                        Text(itemsText(entry.cartCount))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(white: 0.50))
                    }
                    .padding(.top, 4)
                } else {
                    Text("Корзина")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                        .kerning(0.8)
                    Text("Пусто")
                        .font(priceFont(20))
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.top, 1)
                    Text("Добавь товары")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                        .padding(.top, 3)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func itemsText(_ count: Int) -> String {
        let m10 = count % 10, m100 = count % 100
        if m100 >= 11 && m100 <= 19 { return "\(count) товаров" }
        if m10 == 1 { return "\(count) товар" }
        if m10 >= 2 && m10 <= 4 { return "\(count) товара" }
        return "\(count) товаров"
    }
}
