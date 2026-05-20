import SwiftUI
import UIKit
import Kingfisher

struct ProductView: View {
    let uuid: String

    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @StateObject private var vm = ProductViewModel()
    @State private var addedToCart = false
    @State private var shareItem: ShareImageItem? = nil
    @State private var loadedProductImage: UIImage? = nil
    @State private var brandSearchItem: BrandSearchItem? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if vm.isLoading {
                SkeletonProductDetail()
            } else if vm.error != nil, vm.product == nil {
                ProductDetailError {
                    Task { await vm.load(uuid: uuid, cityId: cityStore.selectedCityId) }
                }
            } else if let product = vm.product {
                LazyVStack(alignment: .leading, spacing: 0) {

                    // Hero image
                    ZStack(alignment: .bottom) {
                        // Мягкое свечение-фон
                        ZStack {
                            Color.appCard
                            Color.appPrimary.opacity(0.035)
                        }
                        .frame(height: 280)

                        KFImage(product.coverURL)
                            .placeholder { Rectangle().fill(Color.appCard) }
                            .cancelOnDisappear(true)
                            .onSuccess { result in loadedProductImage = result.image }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)

                        // Fade into page background
                        LinearGradient(
                            colors: [.clear, Color.appBackground],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                    .frame(height: 280)
                    .clipped()

                    LazyVStack(alignment: .leading, spacing: 22) {

                        // Title + brand
                        VStack(alignment: .leading, spacing: 8) {
                            if let brand = product.brand, !brand.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button {
                                    brandSearchItem = BrandSearchItem(brand: brand)
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(brand.uppercased())
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .kerning(1.2)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .black))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 4.5)
                                    .background {
                                        ZStack {
                                            LinearGradient(
                                                colors: [
                                                    Color.appPrimaryLight,
                                                    Color.appPrimary,
                                                    Color.appPrimaryDeep,
                                                ],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                            LinearGradient(
                                                colors: [.white.opacity(0.30), .clear],
                                                startPoint: .top, endPoint: .center
                                            )
                                        }
                                        .clipShape(Capsule())
                                    }
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            Text(product.title)
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .kerning(-0.2)
                                .foregroundStyle(Color.appForeground)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }

                        ProductMetaRow(product: product, range: product.priceRange)

                        // Price hero
                        if let range = product.priceRange {
                            PriceHero(range: range, discountPercent: product.meanMinDiscountPercent)
                        }

                        // Store prices
                        if let stores = product.priceRange?.stores, !stores.isEmpty {
                            StorePricesSection(stores: stores)
                        }

                        // Price history chart — отключаемо через RemoteConfig
                        if let history = vm.priceHistory, !history.stores.isEmpty,
                           ConfigSnapshot.isEnabled(.priceHistoryChart) {
                            PriceHistoryChart(history: history)
                        }

                        // Description
                        if let desc = product.description, !desc.isEmpty {
                            ExpandableDescription(text: desc)
                        }

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            HStack {
                NavGlassButton(icon: "chevron.left") { dismiss() }
                Spacer()
                NavGlassButton(icon: "square.and.arrow.up") { triggerShare() }
                NavGlassButton(
                    icon: favoritesStore.isFavorited(uuid) ? "star.fill" : "star",
                    tint: favoritesStore.isFavorited(uuid) ? Color.appPrimary : Color.appForeground
                ) {
                    if let product = vm.product {
                        HapticManager.success()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            favoritesStore.toggle(product)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { v in
                    if v.translation.width > 80 && abs(v.translation.height) < 80 { dismiss() }
                }
        )
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preference(key: HideBottomBarsKey.self, value: true)
        .safeAreaInset(edge: .bottom) {
            ProductCartBar(
                price: vm.product?.priceRange?.min ?? vm.product?.cheapestPrice,
                added: addedToCart
            ) {
                guard !addedToCart else { return }
                Task {
                    do {
                        try await cartStore.quickAdd(productUuid: uuid)
                        withAnimation { addedToCart = true }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation { addedToCart = false }
                    } catch {}
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ProductSharePreviewSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $brandSearchItem) { item in
            BrandProductsView(brand: item.brand)
        }
        .task { await vm.load(uuid: uuid, cityId: cityStore.selectedCityId) }
    }

    private func triggerShare() {
        guard let product = vm.product else { return }
        let image = makeProductShareImage(product: product, productImage: loadedProductImage) ?? UIImage()
        let url = URL(string: "https://minprice.kz/products/\(product.uuid)/")
        shareItem = ShareImageItem(image: image, url: url, productTitle: product.title)
    }
}

// MARK: - Nav Glass Button

private struct NavGlassButton: View {
    let icon: String
    var tint: Color = Color.appForeground
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
            .background(Color.appCard.opacity(0.94), in: Circle())
            .overlay(Circle().stroke(Color.appBorder.opacity(0.75), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meta Row

private struct ProductMetaRow: View {
    let product: Product
    let range: PriceRange?

    private var discountPercent: Int {
        Int(product.meanMinDiscountPercent.rounded())
    }

    private var storesCount: Int {
        range?.stores.count ?? product.linkedStoresCount ?? product.stores?.count ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if storesCount > 0 {
                    DetailPill(icon: "storefront.fill", text: "\(storesCount) \(storesWord(storesCount))")
                }
                if let measure = measureLabel {
                    DetailPill(icon: "scalemass.fill", text: measure)
                }
                if let packCount = product.packCount, packCount > 1 {
                    DetailPill(icon: "shippingbox.fill", text: "\(packCount) шт")
                }
                if discountPercent >= 20 {
                    DetailPill(icon: "flame.fill", text: "ХИТ", tint: Color.warningAmber)
                }
                if discountPercent > 0 {
                    DetailPill(
                        icon: "arrow.down.right",
                        text: "-\(discountPercent)%",
                        tint: Color.discountRed
                    )
                }
            }
        }
    }

    private var measureLabel: String? {
        guard let qty = product.measureUnitQty?.value, qty > 0 else { return nil }
        let qtyText = qty.rounded() == qty ? "\(Int(qty))" : String(format: "%.1f", qty)
        let unit = normalizedUnit(product.measureUnitKind ?? product.measureUnit)
        guard !unit.isEmpty else { return nil }
        return "\(qtyText) \(unit)"
    }

    private func normalizedUnit(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "g", "gr", "gram", "grams": return "г"
        case "kg": return "кг"
        case "ml": return "мл"
        case "l": return "л"
        case "pcs", "pc", "piece", "шт": return "шт"
        default: return raw ?? ""
        }
    }
}

private struct DetailPill: View {
    let icon: String
    let text: String
    var tint: Color = .appPrimary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.20), lineWidth: 0.7))
    }
}

private func storesWord(_ n: Int) -> String {
    let m10 = n % 10, m100 = n % 100
    if m100 >= 11 && m100 <= 19 { return "магазинов" }
    if m10 == 1 { return "магазин" }
    if m10 >= 2 && m10 <= 4 { return "магазина" }
    return "магазинов"
}

private struct ProductDetailError: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ErrorStateView(
                .networkError,
                retry: retry
            )
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 420)
        .padding(.horizontal, 20)
    }
}

// MARK: - Cart Bar

private struct ProductCartBar: View {
    let price: Double?
    let added: Bool
    let onAddToCart: () -> Void

    var body: some View {
        Button(action: onAddToCart) {
            HStack(spacing: 8) {
                Image(systemName: added ? "checkmark.circle.fill" : "cart.fill.badge.plus")
                    .font(.system(size: 17, weight: .black))
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .kerning(0.2)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background {
                ZStack {
                    if added {
                        LinearGradient(
                            colors: [
                                Color.savingsGreenSoft,
                                Color.savingsGreen,
                                Color.savingsGreenDeep,
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient.brandPrimary
                    }
                    LinearGradient(
                        colors: [.white.opacity(0.30), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
                .clipShape(Capsule())
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.7))
            .scaleEffect(added ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: added)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var title: String {
        if added { return "Добавлено в корзину" }
        if let price { return "В корзину • \(formatPriceTg(price))" }
        return "В корзину"
    }
}

// MARK: - Price Hero

private struct PriceHero: View {
    let range: PriceRange
    let discountPercent: Double

    private var savingsPct: Int? {
        guard discountPercent >= 1 else { return nil }
        return Int(discountPercent.rounded())
    }

    private var savingsAmount: Double? {
        if range.avg > range.min { return range.avg - range.min }
        return nil
    }

    private var hasSaving: Bool { savingsPct != nil }
    private var savingsText: String? {
        guard let savingsAmount else { return nil }
        return formatPriceTg(savingsAmount)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .black))
                    Text(hasSaving ? "Лучшая цена" : "Цена от")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(Color.savingsGreenDeep)
                .padding(.horizontal, 11)
                .padding(.vertical, 6.5)
                .background(Color.savingsGreen.opacity(0.13), in: Capsule())

                if let savingsText {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .black))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("экономия")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.appMuted)
                            Text(savingsText)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(Color.savingsGreenDeep)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatPriceNumber(range.min))
                    .font(.system(size: 68, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.savingsGreenSoft, Color.savingsGreen, Color.savingsGreenDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: range.min)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)

                Text("₸")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.savingsGreen.opacity(0.72))
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color.appCard
                LinearGradient(
                    colors: [
                        Color.savingsGreen.opacity(hasSaving ? 0.16 : 0.10),
                        Color.savingsGreen.opacity(0.03),
                        Color.appPrimary.opacity(hasSaving ? 0.06 : 0.0),
                    ],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )

                HeroLogoPattern()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.savingsGreen.opacity(0.38),
                            Color.savingsGreen.opacity(0.20),
                            Color.appPrimary.opacity(hasSaving ? 0.25 : 0.0),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .animation(.easeInOut(duration: 0.25), value: savingsPct)
    }
}

private struct HeroLogoPattern: View {
    private let items: [(CGFloat, CGFloat, CGFloat, Double, Double)] = [
        (0.06, 0.12, 34, 0.120, -18),
        (0.22, 0.74, 28, 0.095, 14),
        (0.42, 0.20, 24, 0.085, -10),
        (0.55, 0.82, 30, 0.095, 20),
        (0.72, 0.17, 36, 0.110, 16),
        (0.88, 0.66, 26, 0.085, -14),
        (0.96, 0.20, 30, 0.078, 22),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(items.indices, id: \.self) { idx in
                let item = items[idx]
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: item.2, height: item.2)
                    .opacity(item.3)
                    .rotationEffect(.degrees(item.4))
                    .position(x: geo.size.width * item.0, y: geo.size.height * item.1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Store Prices Section

private struct StorePricesSection: View {
    let stores: [PriceRangeStore]
    private var sortedStores: [PriceRangeStore] {
        stores.sorted {
            if $0.inStock != $1.inStock { return $0.inStock && !$1.inStock }
            return $0.price < $1.price
        }
    }
    private var minPrice: Double {
        stores.filter(\.inStock).map(\.price).min() ?? stores.map(\.price).min() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.appPrimary.opacity(0.85))
                Text("Цены в магазинах")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .kerning(0.2)
                    .foregroundStyle(LinearGradient.brandPrimary)
                Spacer()
                Text("\(stores.count)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 7).padding(.vertical, 1.5)
                    .background(Color.appPrimary.opacity(0.12), in: Capsule())
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedStores.enumerated()), id: \.offset) { idx, store in
                    let isBest = store.inStock && abs(store.price - minPrice) < 0.01

                    HStack(spacing: 12) {
                        StoreLogoView(url: store.logoURL, slug: store.chainSlug, source: store.storeSource, size: 36)
                            .opacity(store.inStock ? 1 : 0.35)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(formatStoreName(slug: store.chainSlug, fallback: store.chainName))
                                    .font(.system(size: 15, weight: isBest ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(Color.appForeground)
                                if isBest {
                                    Text("min")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .kerning(0.5)
                                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                                        .background {
                                            ZStack {
                                                LinearGradient(
                                                    colors: [
                                                        Color.appPrimaryLight,
                                                        Color.appPrimary,
                                                        Color.appPrimaryDeep,
                                                    ],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                                LinearGradient(
                                                    colors: [.white.opacity(0.30), .clear],
                                                    startPoint: .top, endPoint: .center
                                                )
                                            }
                                            .clipShape(Capsule())
                                        }
                                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                                }
                            }
                            if !store.inStock {
                                Text("нет в наличии")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.appMuted)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let prev = store.previousPrice, prev > store.price {
                                Text(formatPriceTg(prev))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.appMuted)
                                    .strikethrough()
                            }
                            Text(formatPriceTg(store.price))
                                .font(.system(size: 16, weight: isBest ? .black : .semibold, design: .rounded))
                                .foregroundStyle(
                                    isBest
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color.savingsGreenSoft,
                                                    Color.savingsGreen,
                                                    Color.savingsGreenDeep,
                                                ],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                          )
                                        : AnyShapeStyle(Color.appForeground)
                                )
                                .opacity(store.inStock ? 1 : 0.45)
                        }

                        if let urlStr = store.url, let url = URL(string: urlStr) {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(isBest ? .white : Color.appMuted)
                                    .frame(width: 28, height: 28)
                                    .background {
                                        if isBest {
                                            LinearGradient(
                                                colors: [Color.appPrimary, Color.appPrimaryDeep],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                            .clipShape(Circle())
                                        } else {
                                            Color.appMuted.opacity(0.10).clipShape(Circle())
                                        }
                                    }
                                    .overlay(
                                        Circle().strokeBorder(
                                            isBest ? .white.opacity(0.25) : Color.clear,
                                            lineWidth: 0.5
                                        )
                                    )
                                    .shadow(
                                        color: .clear,
                                        radius: 5, x: 0, y: 2
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 14)
                    .background {
                        if isBest {
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color.appPrimary.opacity(0.10),
                                        Color.appPrimary.opacity(0.03),
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.appPrimary.opacity(0.55), Color.appPrimary.opacity(0.20)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.2
                                    )
                            )
                        }
                    }

                    if idx < sortedStores.count - 1 {
                        Divider().overlay(Color.appBorder).padding(.horizontal, 14)
                    }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
        }
    }
}

// MARK: - Price History Chart

/// Имя сети для графика. На входе используем slug — потому что Wolt-сети
/// (small/galmart/toimart) одинаковый source, разные slug.
private func formatStoreName(slug: String?, fallback raw: String) -> String {
    let key = (slug ?? raw).lowercased().replacingOccurrences(of: " ", with: "")
    switch key {
    case "mgo", "magnumgo":              return "MagnumGO"
    case "airbafresh", "airba":          return "AirbaFresh"
    case "arbuz", "arbuz.kz", "arbuzkz": return "Arbuz.kz"
    case "small":                        return "SMALL"
    case "galmart":                      return "Galmart"
    case "toimart":                      return "Toimart"
    case "wolt":                         return "SMALL" // legacy fallback
    case "kaspi", "kaspimart":           return "Kaspi"
    default:
        if key.contains("magnum") { return "MagnumGO" }
        if key.contains("airba")  { return "AirbaFresh" }
        if key.contains("arbuz")  { return "Arbuz.kz" }
        if key.contains("galmart"){ return "Galmart" }
        if key.contains("toimart"){ return "Toimart" }
        if key.contains("small")  { return "SMALL" }
        if key.contains("kaspi")  { return "Kaspi" }
        // camelCase → spaced words fallback
        var result = ""
        for (i, char) in raw.enumerated() {
            if char.isUppercase && i > 0 {
                let idx = raw.index(raw.startIndex, offsetBy: i)
                let prev = raw[raw.index(before: idx)]
                if prev.isLowercase {
                    result += " "
                } else if i + 1 < raw.count {
                    let next = raw[raw.index(after: idx)]
                    if next.isLowercase { result += " " }
                }
            }
            result += String(char)
        }
        return result
    }
}

// Старая сигнатура — по storeSource. Используется только как fallback в коде.
private func formatStoreName(_ raw: String) -> String {
    formatStoreName(slug: nil, fallback: raw)
}

/// Цвет линии магазина. Идентификация — slug (приоритет) или source (fallback).
private func chartColor(slug: String?, source: String) -> Color {
    BrandPalette.storeColor(slug: slug, source: source)
}

private func chartColor(_ source: String) -> Color {
    BrandPalette.storeColor(slug: nil, source: source)
}

private struct ChartPoint: Identifiable {
    var id: String { "\(chainSource)-\(Int(date.timeIntervalSince1970))-\(Int(price.rounded()))" }
    let store: String
    let chainSource: String
    let date: Date
    let price: Double
}

private struct PriceAxisLabel: Identifiable {
    let id: String
    let value: Double
    let text: String
}

private struct DateAxisLabel: Identifiable {
    let id: String
    let date: Date
    let text: String
}

private struct PriceHistoryChartModel {
    let bestPoints: [ChartPoint]
    let renderPoints: [ChartPoint]
    let periodMin: ChartPoint?
    let periodMax: Double?
    let currentPoint: ChartPoint?
    let dropPercent: Int?
    let savingsAmount: Double?
    let minDate: Date
    let maxDate: Date
    let minPrice: Double
    let maxPrice: Double
    let yLabels: [PriceAxisLabel]
    let xLabels: [DateAxisLabel]

    var isEmpty: Bool { bestPoints.isEmpty }
    var currentMin: Double? { currentPoint?.price }

    static func build(history: PriceHistoryResponse) -> PriceHistoryChartModel {
        let cal = Calendar.current
        var bestByDay: [Date: ChartPoint] = [:]

        for store in history.stores {
            let label = formatStoreName(store.chainSource)
            let grouped = Dictionary(
                grouping: store.prices.compactMap { p -> (Date, Double)? in
                    guard let d = PriceHistoryDateParser.parse(p.datetime) else { return nil }
                    return (cal.startOfDay(for: d), p.price)
                },
                by: { $0.0 }
            )
            for (day, items) in grouped {
                guard let dayMin = items.map(\.1).min(), dayMin > 0 else { continue }
                let point = ChartPoint(
                    store: label,
                    chainSource: store.chainSource,
                    date: day,
                    price: dayMin
                )
                if let existing = bestByDay[day] {
                    if point.price < existing.price {
                        bestByDay[day] = point
                    }
                } else {
                    bestByDay[day] = point
                }
            }
        }

        let allPoints = bestByDay.values.sorted(by: { $0.date < $1.date })
        let renderPoints = Self.downsample(allPoints, maxCount: 48)
        let fallbackDate = Date()
        let minDate = allPoints.map(\.date).min() ?? fallbackDate
        let maxDate = allPoints.map(\.date).max() ?? minDate
        let rawMinPrice = allPoints.map(\.price).min() ?? 0
        let rawMaxPrice = allPoints.map(\.price).max() ?? max(rawMinPrice, 1)
        let pricePadding = max((rawMaxPrice - rawMinPrice) * 0.10, rawMaxPrice > rawMinPrice ? 1 : max(rawMaxPrice * 0.08, 1))
        let chartMinPrice = max(0, rawMinPrice - pricePadding)
        let chartMaxPrice = rawMaxPrice + pricePadding
        let periodMin = allPoints.min(by: { $0.price < $1.price })
        let periodMax = allPoints.map(\.price).max()
        let currentPoint = allPoints.last

        let dropPercent: Int? = {
            guard let high = periodMax, let cur = currentPoint?.price, high > cur else { return nil }
            let pct = Int(((high - cur) / high) * 100)
            return pct >= 1 ? pct : nil
        }()

        let savingsAmount: Double? = {
            guard let high = periodMax, let cur = currentPoint?.price, high > cur else { return nil }
            return high - cur
        }()

        return PriceHistoryChartModel(
            bestPoints: allPoints,
            renderPoints: renderPoints,
            periodMin: periodMin,
            periodMax: periodMax,
            currentPoint: currentPoint,
            dropPercent: dropPercent,
            savingsAmount: savingsAmount,
            minDate: minDate,
            maxDate: maxDate,
            minPrice: chartMinPrice,
            maxPrice: chartMaxPrice,
            yLabels: Self.makeYLabels(min: chartMinPrice, max: chartMaxPrice),
            xLabels: Self.makeXLabels(min: minDate, max: maxDate)
        )
    }

    private static func makeYLabels(min: Double, max: Double) -> [PriceAxisLabel] {
        guard max > min else {
            return [PriceAxisLabel(id: "single-y", value: min, text: formatCompactPrice(min))]
        }
        return [0.0, 0.5, 1.0].map { ratio in
            let value = min + (max - min) * ratio
            return PriceAxisLabel(
                id: "y-\(ratio)",
                value: value,
                text: formatCompactPrice(value)
            )
        }
    }

    private static func makeXLabels(min: Date, max: Date) -> [DateAxisLabel] {
        let span = max.timeIntervalSince(min)
        guard span > 0 else {
            return [DateAxisLabel(id: "single-x", date: min, text: PriceHistoryDateFormatter.short(min))]
        }
        return [0.0, 0.5, 1.0].map { ratio in
            let date = min.addingTimeInterval(span * ratio)
            return DateAxisLabel(
                id: "x-\(ratio)",
                date: date,
                text: PriceHistoryDateFormatter.short(date)
            )
        }
    }

    private static func downsample(_ points: [ChartPoint], maxCount: Int) -> [ChartPoint] {
        guard points.count > maxCount, maxCount >= 8 else { return points }
        let first = points[0]
        let last = points[points.count - 1]
        let bucketSize = Double(points.count - 2) / Double(maxCount - 2)
        var sampled: [ChartPoint] = [first]

        for bucket in 0..<(maxCount - 2) {
            let start = 1 + Int(Double(bucket) * bucketSize)
            let end = min(points.count - 1, 1 + Int(Double(bucket + 1) * bucketSize))
            guard start < end else { continue }
            let slice = points[start..<end]
            let picked = slice.min(by: { $0.price < $1.price }) ?? points[start]
            if picked.id != sampled.last?.id {
                sampled.append(picked)
            }
        }

        if sampled.last?.id != last.id {
            sampled.append(last)
        }
        return sampled.sorted(by: { $0.date < $1.date })
    }
}

private enum PriceHistoryDateParser {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? internet.date(from: value)
    }
}

private enum PriceHistoryDateFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return formatter
    }()

    static func short(_ date: Date) -> String {
        formatter.string(from: date)
    }
}

private struct PriceHistoryChart: View {
    let history: PriceHistoryResponse
    @State private var model: PriceHistoryChartModel
    @State private var modelKey: String

    init(history: PriceHistoryResponse) {
        self.history = history
        let key = Self.makeModelKey(history)
        _model = State(initialValue: PriceHistoryChartModel.build(history: history))
        _modelKey = State(initialValue: key)
    }

    private static func makeModelKey(_ history: PriceHistoryResponse) -> String {
        let storesKey = history.stores
            .map { store in
                "\(store.storeId):\(store.prices.count):\(store.prices.last?.datetime ?? "")"
            }
            .joined(separator: "|")
        return "\(history.productUuid)-\(history.days)-\(storesKey)"
    }

    private var greenSoft: Color { Color.savingsGreenSoft }
    private var greenDeep: Color { Color.savingsGreenDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.appPrimaryLight, Color.appPrimary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(.white.opacity(0.30), lineWidth: 0.6))
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Динамика лучшей цены")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("минимум среди магазинов за \(history.days) \(daysWord(history.days))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                Spacer()

                if let pct = model.dropPercent {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10, weight: .black))
                        Text("\(pct)%")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background {
                        ZStack {
                            LinearGradient(
                                colors: [greenSoft, Color.savingsGreen],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            LinearGradient(
                                colors: [.white.opacity(0.30), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        }
                        .clipShape(Capsule())
                    }
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
                }
            }

            // KPI strip
            HStack(spacing: 8) {
                if let cur = model.currentPoint?.price {
                    KPICell(
                        label: "ЛУЧШАЯ",
                        value: cur,
                        gradient: [greenSoft, Color.savingsGreen, greenDeep],
                        glowColor: Color.savingsGreen
                    )
                }
                if let min = model.periodMin?.price, let cur = model.currentPoint?.price, min < cur {
                    KPICell(
                        label: "МИНИМУМ",
                        value: min,
                        gradient: [
                            Color.appPrimaryLight,
                            Color.appPrimary,
                            Color.appPrimaryDeep,
                        ],
                        glowColor: Color.appPrimary
                    )
                }
                if let max = model.periodMax {
                    KPICell(
                        label: "МАКСИМУМ",
                        value: max,
                        gradient: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.55),
                        ],
                        glowColor: .white,
                        muted: true
                    )
                }
            }

            if let point = model.currentPoint {
                HStack(spacing: 6) {
                    Circle()
                        .fill(chartColor(point.chainSource))
                        .frame(width: 7, height: 7)
                    Text("Сейчас дешевле всего в \(point.store)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    if let savings = model.savingsAmount, savings >= 1 {
                        Text("экономия \(formatCompactPrice(savings))")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(Color.savingsGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            }

            // Chart
            LightweightPriceChart(model: model)
                .frame(height: 190)
        }
        .onChange(of: Self.makeModelKey(history)) { newKey in
            guard newKey != modelKey else { return }
            modelKey = newKey
            model = PriceHistoryChartModel.build(history: history)
        }
        .padding(16)
        .background {
            LinearGradient.chartDark
                .overlay(alignment: .topTrailing) {
                    Color.savingsGreen.opacity(0.08)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .offset(x: 44, y: -52)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }

    private func daysWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "дней" }
        if m10 == 1 { return "день" }
        if m10 >= 2 && m10 <= 4 { return "дня" }
        return "дней"
    }

}

private struct LightweightPriceChart: View {
    let model: PriceHistoryChartModel

    var body: some View {
        StaticPriceHistoryChart(model: model)
        .accessibilityLabel("График истории цен")
    }
}

private struct StaticPriceHistoryChart: UIViewRepresentable {
    let model: PriceHistoryChartModel

    func makeUIView(context: Context) -> PriceHistoryChartUIView {
        let view = PriceHistoryChartUIView()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.contentMode = .redraw
        view.model = model
        return view
    }

    func updateUIView(_ uiView: PriceHistoryChartUIView, context: Context) {
        uiView.model = model
    }
}

private final class PriceHistoryChartUIView: UIView {
    var model: PriceHistoryChartModel? {
        didSet {
            if oldValue?.renderPoints.map(\.id) != model?.renderPoints.map(\.id) {
                setNeedsDisplay()
            }
        }
    }

    private let plotInsets = UIEdgeInsets(top: 12, left: 46, bottom: 28, right: 8)

    override func draw(_ rect: CGRect) {
        guard let model, let context = UIGraphicsGetCurrentContext(), bounds.width > 2, bounds.height > 2 else { return }
        let plot = plotRect(in: bounds)
        guard plot.width > 2, plot.height > 2 else { return }

        context.setShouldAntialias(true)
        drawGrid(model: model, plot: plot)
        drawLine(model: model, plot: plot)
        drawLabels(model: model, plot: plot)
        drawCurrentPoint(model: model, plot: plot)
    }

    private func drawGrid(model: PriceHistoryChartModel, plot: CGRect) {
        UIColor.white.withAlphaComponent(0.08).setStroke()
        let grid = UIBezierPath()
        model.yLabels.forEach { label in
            let y = yPosition(label.value, model: model, plot: plot)
            grid.move(to: CGPoint(x: plot.minX, y: y))
            grid.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        grid.lineWidth = 0.5
        grid.setLineDash([2, 3], count: 2, phase: 0)
        grid.stroke()
    }

    private func drawLine(model: PriceHistoryChartModel, plot: CGRect) {
        let points = model.renderPoints
        guard !points.isEmpty else { return }

        let line = UIBezierPath()
        let area = UIBezierPath()
        for (index, point) in points.enumerated() {
            let p = pointPosition(point, model: model, plot: plot)
            if index == 0 {
                line.move(to: p)
                area.move(to: CGPoint(x: p.x, y: plot.maxY))
                area.addLine(to: p)
            } else {
                line.addLine(to: p)
                area.addLine(to: p)
            }
        }

        if let last = points.last {
            area.addLine(to: CGPoint(x: xPosition(last.date, model: model, plot: plot), y: plot.maxY))
            area.close()
        }

        UIColor(Color.savingsGreen).withAlphaComponent(0.13).setFill()
        area.fill()

        UIColor(Color.savingsGreen).setStroke()
        line.lineWidth = 2.6
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        line.stroke()
    }

    private func drawLabels(model: PriceHistoryChartModel, plot: CGRect) {
        let yAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .heavy),
            .foregroundColor: UIColor.white.withAlphaComponent(0.50)
        ]
        for label in model.yLabels {
            let y = yPosition(label.value, model: model, plot: plot)
            let size = (label.text as NSString).size(withAttributes: yAttributes)
            (label.text as NSString).draw(
                at: CGPoint(x: plot.minX - size.width - 8, y: y - size.height / 2),
                withAttributes: yAttributes
            )
        }

        let xAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9.5, weight: .heavy),
            .foregroundColor: UIColor.white.withAlphaComponent(0.55)
        ]
        for label in model.xLabels {
            let x = xPosition(label.date, model: model, plot: plot)
            let size = (label.text as NSString).size(withAttributes: xAttributes)
            let clampedX = min(max(x - size.width / 2, 0), bounds.width - size.width)
            (label.text as NSString).draw(
                at: CGPoint(x: clampedX, y: plot.maxY + 8),
                withAttributes: xAttributes
            )
        }
    }

    private func drawCurrentPoint(model: PriceHistoryChartModel, plot: CGRect) {
        guard let current = model.currentPoint else { return }
        let center = pointPosition(current, model: model, plot: plot)
        UIColor(Color.appPrimary).withAlphaComponent(0.22).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)).fill()
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9)).fill()
        UIColor(Color.appPrimary).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - 2.25, y: center.y - 2.25, width: 4.5, height: 4.5)).fill()
    }

    private func plotRect(in rect: CGRect) -> CGRect {
        CGRect(
            x: plotInsets.left,
            y: plotInsets.top,
            width: max(1, rect.width - plotInsets.left - plotInsets.right),
            height: max(1, rect.height - plotInsets.top - plotInsets.bottom)
        )
    }

    private func pointPosition(_ point: ChartPoint, model: PriceHistoryChartModel, plot: CGRect) -> CGPoint {
        CGPoint(
            x: xPosition(point.date, model: model, plot: plot),
            y: yPosition(point.price, model: model, plot: plot)
        )
    }

    private func xPosition(_ date: Date, model: PriceHistoryChartModel, plot: CGRect) -> CGFloat {
        let minT = model.minDate.timeIntervalSince1970
        let span = max(model.maxDate.timeIntervalSince1970 - minT, 1)
        let ratio = (date.timeIntervalSince1970 - minT) / span
        return plot.minX + CGFloat(ratio) * plot.width
    }

    private func yPosition(_ price: Double, model: PriceHistoryChartModel, plot: CGRect) -> CGFloat {
        let span = max(model.maxPrice - model.minPrice, 1)
        let ratio = (price - model.minPrice) / span
        return plot.maxY - CGFloat(ratio) * plot.height
    }
}

private func formatCompactPrice(_ value: Double) -> String {
    let absVal = abs(value)
    if absVal >= 10_000 {
        let rounded = Int(value.rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: NSNumber(value: rounded)) ?? String(rounded)
        return "\(formatted) тг"
    }
    return "\(Int(value.rounded())) тг"
}

// MARK: - Expandable Description

private struct ExpandableDescription: View {
    let text: String
    @State private var isExpanded = false

    private let collapsedLineLimit = 4
    private var isLong: Bool { text.count > 220 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.appPrimary.opacity(0.85))
                Text("Описание")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .kerning(0.2)
                    .foregroundStyle(LinearGradient.brandPrimary)
            }

            Text(text)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color.appMuted)
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : collapsedLineLimit)
                .animation(.easeInOut(duration: 0.20), value: isExpanded)

            if isLong {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Свернуть" : "Показать ещё")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.appPrimary.opacity(0.12), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.appPrimary.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.appCard
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

private struct KPICell: View {
    let label: String
    let value: Double
    let gradient: [Color]
    let glowColor: Color
    var muted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(muted ? 0.45 : 0.60))
                .kerning(0.8)
            Text(formatPriceTg(value))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background {
            LinearGradient(
                colors: [.white.opacity(0.10), .white.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.6)
        )
    }

}

private struct FlowLegend: View {
    let stores: [(name: String, source: String)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(stores.enumerated()), id: \.offset) { _, store in
                HStack(spacing: 5) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    chartColor(store.source).opacity(0.95),
                                    chartColor(store.source).opacity(0.65),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 7, height: 7)
                        .shadow(color: chartColor(store.source).opacity(0.6), radius: 3)
                    Text(store.name)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background {
                    LinearGradient(
                        colors: [.white.opacity(0.10), .white.opacity(0.03)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(Capsule())
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.5))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Share

struct ProductSharePreviewSheet: View {
    let item: ShareImageItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                Text("Поделиться")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.brandPrimary)
                    .shadow(color: Color.appPrimary.opacity(0.20), radius: 6, x: 0, y: 0)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollView {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.30), Color.appPrimary.opacity(0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.appPrimary.opacity(0.18), radius: 22, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            Button {
                let vc = UIActivityViewController(activityItems: item.activityItems, applicationActivities: nil)
                vc.completionWithItemsHandler = { type, _, _, _ in if type != nil { dismiss() } }
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let root = scene.windows.first?.rootViewController else { return }
                var top = root
                while let p = top.presentedViewController { top = p }
                top.present(vc, animated: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .black))
                    Text("Поделиться")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .kerning(0.2)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    ZStack {
                        LinearGradient.brandPrimary
                        LinearGradient.brandShimmer
                    }
                    .clipShape(Capsule())
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.7))
                .shadow(color: Color.appPrimary.opacity(0.45), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .padding(.bottom, 4)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.appPrimary.opacity(0.06),
                    Color.appBackground,
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let url: URL?
    let productTitle: String

    var shareText: String {
        let title = productTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = title.isEmpty
            ? "Нашёл выгодное предложение на minprice.kz"
            : "Нашёл выгодное предложение на minprice.kz: \(title)"

        guard let url else { return prefix }
        return "\(prefix)\n\(url.absoluteString)"
    }

    var activityItems: [Any] {
        var items: [Any] = [image]
        items.append(shareText)
        if let url {
            items.append(url)
        }
        return items
    }
}

// MARK: - Brand Products View

struct BrandSearchItem: Identifiable {
    let brand: String
    var id: String { brand }
}

struct BrandProductsView: View {
    let brand: String

    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var cityStore: CityStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = SearchViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if vm.isLoading && vm.results.isEmpty {
                    SkeletonCardGrid(count: 6)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if vm.results.isEmpty && !vm.isLoading {
                    VStack(spacing: 14) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.appMuted.opacity(0.35))
                        Text("Товары бренда не найдены")
                            .font(.jb(15, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(vm.results) { product in
                            NavigationLink(value: product.uuid) {
                                ProductCardWrapper(product: product)
                            }
                            .buttonStyle(.pressScale)
                            .onAppear {
                                if product.uuid == vm.results.last?.uuid {
                                    Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if vm.isLoading {
                        ProgressView()
                            .tint(Color.appPrimary)
                            .padding(.vertical, 16)
                    }

                    Color.clear.frame(height: 100)
                }
            }
            .background(Color.appBackground)
            .navigationTitle(brand)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appForeground)
                            .frame(width: 32, height: 32)
                            .background(Color.appCard, in: Circle())
                            .neumorphicButton()
                    }
                }
            }
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
        }
        .task {
            vm.query = brand
            await vm.searchImmediate(cityId: cityStore.selectedCityId)
        }
    }
}
