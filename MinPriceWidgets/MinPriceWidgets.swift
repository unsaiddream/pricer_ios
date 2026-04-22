import WidgetKit
import SwiftUI
import UIKit

// MARK: - Design System

private extension Color {
    static let wPrimary  = Color(red: 0.07, green: 0.71, blue: 0.84)
    static let wRed      = Color(red: 0.95, green: 0.13, blue: 0.13)
    static let wGreen    = Color(red: 0.08, green: 0.63, blue: 0.35)
    static let wText     = Color(red: 0.07, green: 0.11, blue: 0.20)
    static let wMuted    = Color(red: 0.40, green: 0.47, blue: 0.58)
    static let wBg       = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let wCard     = Color.white
    static let wBorder   = Color(red: 0.88, green: 0.90, blue: 0.93)
}

private func storeLabel(_ source: String?) -> String {
    switch source {
    case "mgo":        return "Magnum"
    case "arbuz":      return "Arbuz"
    case "airbafresh": return "Airba"
    case "small":      return "Small"
    case "astore":     return "Astore"
    default:           return source ?? "—"
    }
}

private func storeColor(_ source: String?) -> Color {
    switch source {
    case "mgo":        return Color(red: 0.93, green: 0.13, blue: 0.14)
    case "arbuz":      return Color(red: 1.00, green: 0.42, blue: 0.21)
    case "airbafresh": return Color(red: 0.10, green: 0.50, blue: 0.95)
    case "small":      return Color(red: 0.55, green: 0.28, blue: 0.95)
    case "astore":     return Color(red: 0.00, green: 0.72, blue: 0.38)
    default:           return .wMuted
    }
}

private func fmt(_ v: Double) -> String {
    let n = NumberFormatter()
    n.numberStyle = .decimal
    n.groupingSeparator = " "
    n.maximumFractionDigits = 0
    return "\(n.string(from: NSNumber(value: v)) ?? "\(Int(v))") ₸"
}

// MARK: - Models

struct WidgetStore: Codable, Hashable {
    let name: String
    let price: Double
    let source: String?
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
    let imageUrl: String?
    let stores: [WidgetStore]

    init(id: String, title: String, brand: String?, minPrice: Double, maxPrice: Double,
         prevMinPrice: Double?, storeSource: String?, imageUrl: String?, stores: [WidgetStore]) {
        self.id = id; self.title = title; self.brand = brand
        self.minPrice = minPrice; self.maxPrice = maxPrice
        self.prevMinPrice = prevMinPrice; self.storeSource = storeSource
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
}

// MARK: - Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let products: [WidgetProduct]
    let images: [String: UIImage]   // productId → pre-downloaded image
    let cartCount: Int
    let cartTotal: Double

    var bestDrop: WidgetProduct? {
        products.compactMap { p -> (WidgetProduct, Int)? in
            guard let d = p.dropPercent else { return nil }
            return (p, d)
        }.max(by: { $0.1 < $1.1 })?.0
    }
}

// MARK: - Mock

private let mockStores: [WidgetStore] = [
    WidgetStore(name: "Magnum",     price: 449_990, source: "mgo",        inStock: true),
    WidgetStore(name: "Arbuz",      price: 469_990, source: "arbuz",      inStock: true),
    WidgetStore(name: "Airba Fresh",price: 499_990, source: "airbafresh", inStock: true),
]

private let mockProducts: [WidgetProduct] = [
    WidgetProduct(id: "1", title: "iPhone 15 Pro 256GB",
                  brand: "Apple", minPrice: 449_990, maxPrice: 499_990,
                  prevMinPrice: 559_990, storeSource: "mgo", imageUrl: nil, stores: mockStores),
    WidgetProduct(id: "2", title: "Молоко Простоквашино 3.2%",
                  brand: "Простоквашино", minPrice: 650, maxPrice: 820,
                  prevMinPrice: 820, storeSource: "arbuz", imageUrl: nil,
                  stores: [
                    WidgetStore(name: "Arbuz", price: 650, source: "arbuz", inStock: true),
                    WidgetStore(name: "Small", price: 720, source: "small", inStock: true),
                  ]),
]

// MARK: - Provider

struct MinPriceProvider: TimelineProvider {
    private let suite = "group.kz.minprice.shared"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), products: mockProducts, images: [:], cartCount: 3, cartTotal: 12_400)
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

        // Download images concurrently
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
            for await (id, img) in group {
                if let img { result[id] = img }
            }
            return result
        }
    }
}

// MARK: - Shared Components

private struct WProductImage: View {
    let image: UIImage?

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LinearGradient(
                colors: [Color.wPrimary.opacity(0.12), Color.wCard],
                startPoint: .topTrailing, endPoint: .bottomLeading
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WDiscountSticker: View {
    let percent: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.wRed)
                .shadow(color: Color.wRed.opacity(0.35), radius: 4, x: 0, y: 2)
            Text("−\(percent)%")
                .font(.system(size: size * 0.27, weight: .black))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
    }
}

private struct WEmptyView: View {
    let icon: String; let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22))
                .foregroundStyle(Color.wMuted.opacity(0.5))
            Text(text).font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.wMuted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func storeAsset(_ source: String?) -> String? {
    switch source {
    case "mgo":        return "store_magnum"
    case "arbuz":      return "store_arbuz"
    case "airbafresh": return "store_airba_fresh"
    case "small":      return "store_small"
    case "astore":     return "store_astore"
    default:           return nil
    }
}

private struct WStoreLogo: View {
    let source: String?
    var size: CGFloat = 18

    var body: some View {
        if let asset = storeAsset(source) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            Circle()
                .fill(storeColor(source))
                .frame(width: size * 0.45, height: size * 0.45)
        }
    }
}

private struct WStoreRow: View {
    let store: WidgetStore
    let isBest: Bool

    var body: some View {
        HStack(spacing: 5) {
            WStoreLogo(source: store.source, size: 18)

            Text(store.name)
                .font(.system(size: 10, weight: isBest ? .semibold : .regular))
                .foregroundStyle(isBest ? Color.wText : Color.wMuted)
                .lineLimit(1)

            if isBest {
                Text("min")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.wPrimary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.wPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
            }

            Spacer(minLength: 0)

            Text(fmt(store.price))
                .font(.system(size: 11, weight: isBest ? .bold : .regular))
                .foregroundStyle(isBest ? Color.wText : Color.wMuted)
        }
        .opacity(store.inStock ? 1.0 : 0.45)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isBest ? Color.wPrimary.opacity(0.06) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            isBest ? RoundedRectangle(cornerRadius: 6)
                .stroke(Color.wPrimary.opacity(0.18), lineWidth: 1) : nil
        )
    }
}

// MARK: ═══════════════════════════════
// MARK: WIDGET 1 — FAVORITES
// MARK: ═══════════════════════════════

struct FavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.favorites", provider: MinPriceProvider()) { entry in
            FavoritesView(entry: entry)
                .containerBackground(Color.wBg, for: .widget)
        }
        .configurationDisplayName("Избранное")
        .description("Товары с ценами по магазинам.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct FavoritesView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.products.isEmpty {
            WEmptyView(icon: "heart", text: "Нет избранных товаров")
        } else {
            switch family {
            case .systemMedium: FavMedium(product: entry.products[0], images: entry.images)
            case .systemLarge:  FavLarge(products: entry.products, images: entry.images)
            default:            FavSmall(product: entry.products[0], images: entry.images)
            }
        }
    }
}

// Small
private struct FavSmall: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WProductImage(image: images[product.id])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if let pct = product.dropPercent {
                    WDiscountSticker(percent: pct, size: 42)
                        .offset(x: 4, y: -4).padding(.trailing, 4).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 95, maxHeight: 95)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.system(size: 11)).foregroundStyle(Color.wText.opacity(0.85))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt(product.minPrice))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.wText)
                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        Text(fmt(prev))
                            .font(.system(size: 9)).foregroundStyle(Color.wMuted).strikethrough()
                    }
                }
                HStack(spacing: 4) {
                    WStoreLogo(source: product.storeSource, size: 14)
                    Text(storeLabel(product.storeSource))
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Color.wMuted)
                }
            }
            .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 8)
        }
        .background(Color.wCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
        .padding(8)
    }
}

// Medium — image left, stores right
private struct FavMedium: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WProductImage(image: images[product.id])
                    .frame(maxHeight: .infinity).clipped()
                if let pct = product.dropPercent {
                    WDiscountSticker(percent: pct, size: 46)
                        .offset(x: 4, y: -4).padding(.trailing, 4).padding(.top, 6)
                }
            }
            .frame(width: 130)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.leading, 8).padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.title)
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.wText)
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(fmt(product.minPrice))
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Color.wText)
                        if let prev = product.prevMinPrice, prev > product.minPrice {
                            Text(fmt(prev))
                                .font(.system(size: 10)).foregroundStyle(Color.wMuted).strikethrough()
                        }
                    }
                }
                .padding(.bottom, 6)

                Divider().overlay(Color.wBorder).padding(.bottom, 5)

                if product.stores.isEmpty {
                    Text(storeLabel(product.storeSource))
                        .font(.system(size: 10)).foregroundStyle(Color.wMuted)
                } else {
                    VStack(spacing: 2) {
                        ForEach(Array(product.stores.prefix(3).enumerated()), id: \.offset) { i, store in
                            WStoreRow(store: store, isBest: i == 0)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 10)
        }
        .background(Color.wCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(8)
    }
}

// Large — все товары одинаковыми строками
private struct FavLarge: View {
    let products: [WidgetProduct]
    let images: [String: UIImage]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(products.prefix(3).enumerated()), id: \.element.id) { _, p in
                FavLargeRow(product: p, images: images)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(8)
    }
}

private struct FavLargeRow: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        HStack(spacing: 0) {
            // Фото слева
            ZStack(alignment: .topTrailing) {
                WProductImage(image: images[product.id])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if let pct = product.dropPercent {
                    WDiscountSticker(percent: pct, size: 36)
                        .offset(x: 3, y: -3).padding(.trailing, 3).padding(.top, 4)
                }
            }
            .frame(width: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(8)

            // Текст и магазины справа
            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.wText)
                    .lineLimit(2)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt(product.minPrice))
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.wText)
                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        Text(fmt(prev))
                            .font(.system(size: 9)).foregroundStyle(Color.wMuted).strikethrough()
                    }
                }

                if let saved = product.savings {
                    Text("−\(fmt(saved))")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.wGreen)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.wGreen.opacity(0.10), in: Capsule())
                }

                Divider().overlay(Color.wBorder).padding(.vertical, 1)

                VStack(spacing: 2) {
                    ForEach(Array(product.stores.prefix(2).enumerated()), id: \.offset) { i, store in
                        WStoreRow(store: store, isBest: i == 0)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 8).padding(.bottom, 8).padding(.trailing, 8)
        }
        .background(Color.wCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

// MARK: ═══════════════════════════════
// MARK: WIDGET 2 — PRICE DROP
// MARK: ═══════════════════════════════

struct PriceDropWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.pricedrop", provider: MinPriceProvider()) { entry in
            PriceDropView(entry: entry)
                .containerBackground(Color.wBg, for: .widget)
        }
        .configurationDisplayName("Падение цен")
        .description("Лучшая скидка среди избранных.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct PriceDropView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let product = entry.bestDrop ?? entry.products.first {
            switch family {
            case .systemMedium: FavMedium(product: product, images: entry.images)
            default:            DropSmall(product: product, images: entry.images)
            }
        } else {
            WEmptyView(icon: "arrow.down.circle", text: "Нет избранных")
        }
    }
}

private struct DropSmall: View {
    let product: WidgetProduct
    let images: [String: UIImage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                WProductImage(image: images[product.id])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                if let pct = product.dropPercent {
                    WDiscountSticker(percent: pct, size: 50)
                        .offset(x: 4, y: -4).padding(.trailing, 4).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.title)
                    .font(.system(size: 11)).foregroundStyle(Color.wText.opacity(0.80))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(fmt(product.minPrice))
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.wText)
                    if let prev = product.prevMinPrice, prev > product.minPrice {
                        Text(fmt(prev))
                            .font(.system(size: 10)).foregroundStyle(Color.wMuted).strikethrough()
                    }
                }

                if let saved = product.savings {
                    Text("−\(fmt(saved))")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.wGreen)
                }
            }
            .padding(.horizontal, 8).padding(.top, 7).padding(.bottom, 8)
        }
        .background(Color.wCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(8)
    }
}

// MARK: ═══════════════════════════════
// MARK: WIDGET 3 — CART
// MARK: ═══════════════════════════════

struct CartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "kz.minprice.cart", provider: MinPriceProvider()) { entry in
            CartWidgetView(entry: entry)
                .containerBackground(Color.wBg, for: .widget)
        }
        .configurationDisplayName("Корзина")
        .description("Сумма и количество товаров.")
        .supportedFamilies([.systemSmall])
    }
}

private struct CartWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ZStack {
                    Circle().fill(Color.wPrimary.opacity(0.12)).frame(width: 30, height: 30)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.wPrimary)
                }
                Text("Корзина")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.wText)
                Spacer()
            }

            Spacer()

            if entry.cartCount > 0 {
                Text(fmt(entry.cartTotal))
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(Color.wPrimary)
                    .minimumScaleFactor(0.65).lineLimit(1)
                Text(itemsText(entry.cartCount))
                    .font(.system(size: 11)).foregroundStyle(Color.wMuted).padding(.top, 1)
            } else {
                Text("Пусто").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.wMuted)
                Text("Добавь товары")
                    .font(.system(size: 11)).foregroundStyle(Color.wMuted.opacity(0.6)).padding(.top, 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.wCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(8)
    }

    private func itemsText(_ count: Int) -> String {
        let m10 = count % 10, m100 = count % 100
        if m100 >= 11 && m100 <= 19 { return "\(count) товаров" }
        if m10 == 1 { return "\(count) товар" }
        if m10 >= 2 && m10 <= 4 { return "\(count) товара" }
        return "\(count) товаров"
    }
}
