import SwiftUI
import Kingfisher

// Unified display model — merges StorePrice (list endpoints) and PriceRangeStore (detail endpoint)
private struct StoreSlot {
    let id: Int
    let chainName: String
    let chainSlug: String?
    let storeSource: String
    let logoURL: URL?
    let price: Double
    let previousPrice: Double?
    let inStock: Bool
}

struct ProductCard: View, Equatable {
    let product: Product
    var cartCount: Int = 0
    var onAdd: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    static func == (lhs: ProductCard, rhs: ProductCard) -> Bool {
        lhs.product.uuid == rhs.product.uuid &&
        lhs.product.cheapestPrice == rhs.product.cheapestPrice &&
        lhs.product.priceRange?.min == rhs.product.priceRange?.min &&
        lhs.product.stores?.count == rhs.product.stores?.count &&
        lhs.cartCount == rhs.cartCount
    }

    private var slots: [StoreSlot] {
        // Prefer stores[] (list endpoints). Fall back to priceRange.stores (detail endpoint).
        if let s = product.stores, !s.isEmpty {
            return deduplicatedSlots(s.map {
                StoreSlot(id: $0.storeId, chainName: $0.chainName, chainSlug: $0.chainSlug,
                          storeSource: $0.storeSource,
                          logoURL: $0.logoURL, price: $0.price, previousPrice: $0.previousPrice, inStock: $0.inStock)
            })
        }
        if let s = product.priceRange?.stores, !s.isEmpty {
            return deduplicatedSlots(s.map {
                StoreSlot(id: $0.chainId, chainName: $0.chainName, chainSlug: $0.chainSlug,
                          storeSource: $0.storeSource,
                          logoURL: $0.logoURL, price: $0.price, previousPrice: $0.previousPrice, inStock: $0.inStock)
            })
        }
        return []
    }

    // Один магазин на сеть — берём самый дешёвый экземпляр.
    // Убирает дубли Small/Galmart/Toimart когда у сети несколько точек в городе.
    // Ключ — chainSlug (если есть), иначе chainName, иначе storeSource — потому что
    // у Wolt-сетей storeSource одинаковый, но chainSlug различает их (small/galmart/toimart).
    private func deduplicatedSlots(_ all: [StoreSlot]) -> [StoreSlot] {
        var best: [String: StoreSlot] = [:]
        for slot in all {
            let key = (slot.chainSlug?.lowercased())
                ?? slot.chainName.lowercased()
            if let existing = best[key] {
                if slot.price < existing.price { best[key] = slot }
            } else {
                best[key] = slot
            }
        }
        return Array(best.values.sorted(by: { $0.price < $1.price }).prefix(3))
    }

    private var bestSlot: StoreSlot? {
        slots.filter { $0.inStock }.min(by: { $0.price < $1.price }) ?? slots.first
    }

    private var displayPrice: Double? {
        bestSlot?.price ?? product.priceRange?.min ?? product.cheapestPrice
    }

    private var oldPrice: Double? {
        guard let b = bestSlot, let prev = b.previousPrice, prev > b.price else { return nil }
        return prev
    }

    // Middle-truncation: keeps first 3 words + "…" + last 2 words (weight/size info)
    private var smartTitle: String {
        let title = product.title
        guard title.count > 42 else { return title }
        let words = title.components(separatedBy: " ")
        guard words.count > 5 else { return title }
        let prefix = words.prefix(3).joined(separator: " ")
        let suffix = words.suffix(2).joined(separator: " ")
        guard !prefix.hasSuffix(suffix) else { return title }
        return "\(prefix)… \(suffix)"
    }

    private var discountPercent: Int? {
        if let b = bestSlot, let prev = b.previousPrice, prev > b.price {
            let pct = Int(((prev - b.price) / prev) * 100)
            return pct > 0 ? pct : nil
        }
        if let pct = product.priceRange?.savingsPercent, pct > 0 { return Int(pct) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Image — downsample до карточного размера, иначе держим JPEG в исходном (1500×1500)
            ZStack {
                Color.appCard
                KFImage(product.coverURL)
                    .placeholder {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color.appMuted.opacity(0.3))
                    }
                    .downsampled(to: CGSize(width: 200, height: 130))
                    .fade(duration: 0.18)
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 130)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                // Trading-style delta-чип вместо большого красного DiscountChip:
                // маленький "-12% ▼" — как в финансовых терминалах.
                if let pct = discountPercent {
                    HStack(spacing: 2) {
                        Text("−\(pct)%")
                            .font(.mono(11, weight: .bold))
                        Text("▼")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.discountRed, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    .shadow(color: Color.discountRed.opacity(0.40), radius: 4, x: 0, y: 2)
                    .padding(8)
                }
            }

            // Price + name
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let price = displayPrice {
                        Text(formatPriceTg(price))
                            .font(.mono(17, weight: .bold))
                            .foregroundStyle(oldPrice != nil ? Color.savingsGreen : Color.appForeground)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.2), value: price)
                    }
                    if let prev = oldPrice {
                        Text(formatPriceTg(prev))
                            .font(.mono(11))
                            .foregroundStyle(Color.appMuted)
                            .strikethrough()
                    }
                    Spacer()
                }

                Text(smartTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appForeground.opacity(0.85))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 32, alignment: .top)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Store comparison grid — 3 колонки горизонтально, как было раньше
            Divider().overlay(Color.appBorder)
            StoreGrid(slots: slots, bestId: bestSlot?.id, linkedCount: product.linkedStoresCount)
                .frame(height: 64)
                .padding(.horizontal, 8)

            // Cart button / stepper
            if cartCount > 0 {
                HStack(spacing: 0) {
                    Button(action: { onRemove?() }) {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 38)
                    }
                    Text("\(cartCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                    Button(action: { onAdd?() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 38)
                    }
                }
                .foregroundStyle(Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color.appPrimary.opacity(0.12))
            } else {
                Button(action: { onAdd?() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        if let price = displayPrice {
                            Text(formatPriceTg(price))
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Text("В корзину")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.appPrimary.opacity(0.08))
                }
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appPrimary.opacity(0.18), lineWidth: 1))
        .compositingGroup() // схлопываем layer — тень рисуется один раз, не каждый кадр
        .neumorphicCard(radius: 16)
    }
}

// MARK: - Store comparison grid (горизонтально, центрировано)
// Колонка фиксированной ширины (1/3 карточки), Spacer'ы по краям —
// 1 магазин → в середине карточки, 2 → пара по центру, 3 → заполняют.

private struct StoreGrid: View {
    let slots: [StoreSlot]
    let bestId: Int?
    let linkedCount: Int?

    var body: some View {
        if slots.isEmpty {
            HStack(spacing: 5) {
                if let count = linkedCount, count > 0 {
                    Image(systemName: "storefront")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                    Text("\(count) \(storesWord(count))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // GeometryReader даёт реальную ширину карточки — делим на 3,
            // получаем фиксированный размер колонки независимо от числа магазинов.
            // Spacer'ы по краям центрируют группу из 1-2 элементов.
            GeometryReader { geo in
                let colWidth = geo.size.width / 3
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(0..<slots.count, id: \.self) { i in
                        storeColumn(slots[i])
                            .frame(width: colWidth)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    @ViewBuilder
    private func storeColumn(_ slot: StoreSlot) -> some View {
        let isBest = slot.id == bestId
        VStack(spacing: 3) {
            StoreLogoView(url: slot.logoURL, slug: slot.chainSlug, source: slot.storeSource, size: 22)
                .opacity(slot.inStock ? 1.0 : 0.4)
            // Прайс моноширинно (JetBrainsMono) — все колонки выравниваются
            // как в биржевой таблице.
            Text(formatPriceTg(slot.price))
                .font(.mono(10, weight: isBest ? .bold : .regular))
                .foregroundStyle(isBest ? Color.appPrimary : Color.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if isBest {
                Text("MIN")
                    .font(.mono(7, weight: .bold))
                    .foregroundStyle(Color.appPrimary)
                    .kerning(0.8)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.appPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
            } else {
                Color.clear.frame(height: 13)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Discount chip

private struct DiscountChip: View {
    let percent: Int
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.down.right")
                .font(.system(size: 8, weight: .black))
            Text("\(percent)%")
                .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.discountRed.opacity(0.95),
                        Color.discountRedDeep,
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
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
        .shadow(color: Color.discountRed.opacity(0.40), radius: 6, x: 0, y: 2)
    }
}

private func storesWord(_ n: Int) -> String {
    let m10 = n % 10, m100 = n % 100
    if m100 >= 11 && m100 <= 19 { return "магазинов" }
    if m10 == 1 { return "магазин" }
    if m10 >= 2 && m10 <= 4 { return "магазина" }
    return "магазинов"
}
