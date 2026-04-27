import SwiftUI
import Charts
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
            } else if let product = vm.product {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero image
                    ZStack(alignment: .bottom) {
                        // Мягкое свечение-фон
                        ZStack {
                            Color.white
                            GeometryReader { geo in
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [Color.appPrimary.opacity(0.10), .clear],
                                            center: .center, startRadius: 0, endRadius: 140
                                        )
                                    )
                                    .frame(width: 260, height: 260)
                                    .offset(x: geo.size.width / 2 - 130, y: 30)
                                    .blur(radius: 8)
                            }
                        }
                        .frame(height: 280)

                        KFImage(product.coverURL)
                            .placeholder { Rectangle().fill(Color.appCard) }
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

                    VStack(alignment: .leading, spacing: 22) {

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
                                    .shadow(color: Color.appPrimary.opacity(0.40), radius: 6, x: 0, y: 2)
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

                        // Price hero
                        if let range = product.priceRange {
                            PriceHero(range: range)
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
            ProductCartBar(added: addedToCart) {
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
        shareItem = ShareImageItem(image: image, url: url)
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
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cart Bar

private struct ProductCartBar: View {
    let added: Bool
    let onAddToCart: () -> Void

    var body: some View {
        Button(action: onAddToCart) {
            HStack(spacing: 8) {
                Image(systemName: added ? "checkmark.circle.fill" : "cart.fill.badge.plus")
                    .font(.system(size: 17, weight: .black))
                Text(added ? "Добавлено в корзину" : "В корзину")
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
            .shadow(color: (added ? Color.savingsGreen : Color.appPrimary).opacity(0.45), radius: 14, x: 0, y: 6)
            .scaleEffect(added ? 0.97 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: added)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Price Hero

private struct PriceHero: View {
    let range: PriceRange

    private var savingsPct: Int? {
        guard let pct = range.savingsPercent, pct >= 1 else { return nil }
        return Int(pct)
    }

    private var savingsAmount: Double? {
        if let s = range.savings, s > 0 { return s }
        if range.avg > range.min { return range.avg - range.min }
        return nil
    }

    private var hasSaving: Bool { savingsPct != nil }

    private var greenSoft: Color { Color.savingsGreenSoft }
    private var greenDeep: Color { Color.savingsGreenDeep }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Верхняя строка: лучшая цена + бейджи справа ──
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: hasSaving ? "sparkles" : "tag.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.savingsGreen.opacity(0.85))
                    Text(hasSaving ? "ЛУЧШАЯ ЦЕНА" : "ОТ")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color.savingsGreen.opacity(0.85))
                }

                Spacer()

                // ХИТ + скидка % — компактно справа
                HStack(spacing: 6) {
                    if let pct = savingsPct, pct >= 20 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8, weight: .black))
                            Text("ХИТ")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .kerning(0.6)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background {
                            ZStack {
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.55, blue: 0.20), Color(red: 0.95, green: 0.30, blue: 0.20)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                LinearGradient(colors: [.white.opacity(0.30), .clear], startPoint: .top, endPoint: .center)
                            }
                            .clipShape(Capsule())
                        }
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: Color(red: 0.95, green: 0.40, blue: 0.20).opacity(0.45), radius: 5, x: 0, y: 2)
                    }

                    if let pct = savingsPct {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 10, weight: .black))
                            Text("\(pct)%")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background {
                            ZStack {
                                LinearGradient(
                                    colors: [Color.discountRed.opacity(0.95), Color.discountRedDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                LinearGradient(colors: [.white.opacity(0.30), .clear], startPoint: .top, endPoint: .center)
                            }
                            .clipShape(Capsule())
                        }
                        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
                        .shadow(color: Color.discountRed.opacity(0.40), radius: 7, x: 0, y: 3)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
            }

            // ── Hero price — большая, центральная ──
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatted(range.min))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .kerning(-1.0)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [greenSoft, Color.savingsGreen, greenDeep],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.savingsGreen.opacity(hasSaving ? 0.40 : 0.20), radius: 14, x: 0, y: 0)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: range.min)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("₸")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.savingsGreen.opacity(0.65))

                Spacer(minLength: 0)
            }

            // ── Нижняя полоса: «обычно» / «выгода» ──
            if hasSaving {
                HStack(spacing: 8) {
                    // Обычно
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.appMuted)
                        Text("обычно")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.appMuted)
                        Text("\(formatted(range.avg)) ₸")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.appForeground.opacity(0.65))
                            .strikethrough(true, color: Color.appMuted.opacity(0.5))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.appMuted.opacity(0.10), in: Capsule())

                    // Выгода
                    if let saving = savingsAmount {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .black))
                            Text("экономия")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                            Text("\(formatted(saving)) ₸")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color.savingsGreenDeep)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background {
                            LinearGradient(
                                colors: [greenSoft.opacity(0.25), Color.savingsGreen.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            .clipShape(Capsule())
                        }
                        .overlay(Capsule().strokeBorder(Color.savingsGreen.opacity(0.30), lineWidth: 0.6))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                // Многослойный фон: appCard + двойной радиальный glow + тонкий бирюзовый акцент
                Color.appCard

                LinearGradient(
                    colors: [
                        Color.savingsGreen.opacity(hasSaving ? 0.16 : 0.10),
                        Color.savingsGreen.opacity(0.03),
                        Color.appPrimary.opacity(hasSaving ? 0.06 : 0.0),
                    ],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )

                GeometryReader { geo in
                    // Главный зелёный glow в правом верхнем
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.savingsGreen.opacity(0.32), .clear],
                                center: .center, startRadius: 0, endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(x: geo.size.width - 90, y: -70)
                        .blur(radius: 8)

                    // Бирюзовый glow в левом нижнем (только при скидке)
                    if hasSaving {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.appPrimary.opacity(0.22), .clear],
                                    center: .center, startRadius: 0, endRadius: 90
                                )
                            )
                            .frame(width: 160, height: 160)
                            .offset(x: -60, y: geo.size.height - 60)
                            .blur(radius: 10)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(
            // Двойная обводка — внешний градиент + внутренний шиммер
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.savingsGreen.opacity(0.55),
                            Color.savingsGreen.opacity(0.20),
                            Color.appPrimary.opacity(hasSaving ? 0.25 : 0.0),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.savingsGreen.opacity(hasSaving ? 0.20 : 0.10), radius: 18, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.25), value: savingsPct)
    }

    private func formatted(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }
}


// MARK: - Store Prices Section

private struct StorePricesSection: View {
    let stores: [PriceRangeStore]
    private var minPrice: Double { stores.map(\.price).min() ?? 0 }

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
                ForEach(Array(stores.enumerated()), id: \.offset) { idx, store in
                    let isBest = store.price == minPrice

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
                                        .shadow(color: Color.appPrimary.opacity(0.40), radius: 5, x: 0, y: 2)
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
                                Text("\(Int(prev)) ₸")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Color.appMuted)
                                    .strikethrough()
                            }
                            Text("\(Int(store.price)) ₸")
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
                                        color: isBest ? Color.appPrimary.opacity(0.35) : .clear,
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
                                GeometryReader { geo in
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [Color.appPrimary.opacity(0.18), .clear],
                                                center: .center, startRadius: 0, endRadius: 60
                                            )
                                        )
                                        .frame(width: 110, height: 110)
                                        .offset(x: -30, y: geo.size.height / 2 - 55)
                                        .blur(radius: 4)
                                }
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

                    if idx < stores.count - 1 {
                        Divider().overlay(Color.appBorder).padding(.horizontal, 14)
                    }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
    let id = UUID()
    let store: String
    let chainSource: String
    let date: Date
    let price: Double
}

private struct PriceHistoryChart: View {
    let history: PriceHistoryResponse

    // Минимум за день по каждому магазину, отсортировано по дате —
    // убирает зигзаги от нескольких замеров в сутки и нерегулярных интервалов.
    private var dailyByStore: [(label: String, source: String, points: [ChartPoint])] {
        let cal = Calendar.current
        return history.stores.map { store in
            let label = formatStoreName(store.chainSource)
            let grouped = Dictionary(
                grouping: store.prices.compactMap { p -> (Date, Double)? in
                    guard let d = p.parsedDate else { return nil }
                    return (cal.startOfDay(for: d), p.price)
                },
                by: { $0.0 }
            )
            let pts = grouped.map { (day, items) in
                ChartPoint(
                    store: label,
                    chainSource: store.chainSource,
                    date: day,
                    price: items.map(\.1).min() ?? 0
                )
            }
            .sorted(by: { $0.date < $1.date })
            return (label, store.chainSource, pts)
        }
    }

    private var allPoints: [ChartPoint] {
        dailyByStore.flatMap(\.points)
    }

    private var visibleStores: [(name: String, source: String)] {
        var seen = Set<String>()
        var result: [(name: String, source: String)] = []
        for s in history.stores {
            let name = formatStoreName(s.chainSource)
            if seen.insert(name).inserted {
                result.append((name, s.chainSource))
            }
        }
        return result
    }

    private var periodMin: ChartPoint? { allPoints.min(by: { $0.price < $1.price }) }
    private var periodMax: Double? { allPoints.map(\.price).max() }
    private var currentMin: Double? {
        guard let latest = allPoints.map(\.date).max() else { return nil }
        return allPoints.filter { $0.date == latest }.map(\.price).min()
            ?? allPoints.sorted(by: { $0.date > $1.date }).first?.price
    }

    private var dropPercent: Int? {
        guard let high = periodMax, let cur = currentMin, high > cur else { return nil }
        let pct = Int(((high - cur) / high) * 100)
        return pct >= 1 ? pct : nil
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
                            .fill(Color.appPrimary.opacity(0.40))
                            .frame(width: 30, height: 30)
                            .blur(radius: 8)
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
                        Text("История цен")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("за \(history.days) \(daysWord(history.days))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(0.3)
                    }
                }

                Spacer()

                if let pct = dropPercent {
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
                    .shadow(color: Color.savingsGreen.opacity(0.45), radius: 6, x: 0, y: 2)
                }
            }

            // KPI strip
            HStack(spacing: 8) {
                if let cur = currentMin {
                    KPICell(
                        label: "СЕЙЧАС",
                        value: cur,
                        gradient: [greenSoft, Color.savingsGreen, greenDeep],
                        glowColor: Color.savingsGreen
                    )
                }
                if let min = periodMin?.price, let cur = currentMin, min < cur {
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
                if let max = periodMax {
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

            // Chart
            chartBody
                .frame(height: 190)

            // Legend pills
            if visibleStores.count > 1 {
                FlowLegend(stores: visibleStores)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient.chartDark
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appPrimary.opacity(0.30), .clear],
                                center: .center, startRadius: 0, endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(x: -60, y: -50)
                        .blur(radius: 14)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.savingsGreen.opacity(0.28), .clear],
                                center: .center, startRadius: 0, endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .offset(x: geo.size.width - 80, y: geo.size.height - 80)
                        .blur(radius: 16)
                }
                // Тонкая решётка
                GeometryReader { geo in
                    Path { path in
                        let step: CGFloat = 28
                        var x: CGFloat = 0
                        while x < geo.size.width {
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geo.size.height))
                            x += step
                        }
                    }
                    .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
                }
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
        .shadow(color: Color.appPrimary.opacity(0.18), radius: 18, x: 0, y: 6)
    }

    private var chartBody: some View {
        Chart {
            // Тонкая горизонтальная пунктирная линия на уровне минимума —
            // даёт глазу референс «куда смотреть»
            if let mp = periodMin {
                RuleMark(y: .value("min", mp.price))
                    .foregroundStyle(Color.savingsGreen.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }

            // Линии магазинов: данные агрегированы по дням (мин. цена за сутки)
            ForEach(Array(dailyByStore.enumerated()), id: \.offset) { _, entry in
                let color = chartColor(entry.source)
                ForEach(entry.points) { point in
                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Цена", point.price),
                        series: .value("Магазин", entry.label)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }

            // Точка минимума периода — компактная без аннотации
            if let mp = periodMin {
                PointMark(
                    x: .value("Дата", mp.date),
                    y: .value("Цена", mp.price)
                )
                .symbol {
                    ZStack {
                        Circle()
                            .fill(Color.savingsGreen.opacity(0.40))
                            .frame(width: 16, height: 16)
                            .blur(radius: 3)
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(Color.savingsGreen)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.top, 8).padding(.trailing, 8)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                    .foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let intVal = value.as(Double.self) {
                        Text(formatCompactPrice(intVal))
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func formatCompactPrice(_ v: Double) -> String {
        if v >= 1000 { return "\(Int(v / 1000))k ₸" }
        return "\(Int(v)) ₸"
    }

    private func daysWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "дней" }
        if m10 == 1 { return "день" }
        if m10 >= 2 && m10 <= 4 { return "дня" }
        return "дней"
    }

    private func formatPrice(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? String(Int(v))) ₸"
    }
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
            ZStack {
                Color.appCard
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appPrimary.opacity(0.10), .clear],
                                center: .center, startRadius: 0, endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .offset(x: -40, y: -40)
                        .blur(radius: 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
            Text(formatPrice(value))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .shadow(color: glowColor.opacity(muted ? 0 : 0.40), radius: 6, x: 0, y: 0)
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

    private func formatPrice(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? String(Int(v))) ₸"
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

    var activityItems: [Any] {
        var items: [Any] = [image]
        if let url {
            items.append("Нашёл выгодное предложение на minprice.kz\n\(url.absoluteString)")
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
                                ProductCard(product: product) {
                                    Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                }.equatable()
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
