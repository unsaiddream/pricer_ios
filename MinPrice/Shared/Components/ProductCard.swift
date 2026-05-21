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
        let pct = Int(product.meanMinDiscountPercent.rounded())
        return pct > 0 ? pct : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Color.appBackground.opacity(0.55)
                KFImage(product.coverURL)
                    .placeholder {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color.appMuted.opacity(0.3))
                    }
                    .downsampled(to: CGSize(width: 220, height: 150))
                    .fade(duration: 0.18)
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 132)
            }
            .frame(height: 144)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topLeading) {
                if let pct = discountPercent {
                    DiscountChip(percent: pct).padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Spacer(minLength: 4)
                    if let prev = oldPrice {
                        Text(formatPriceTg(prev))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.appMuted)
                            .strikethrough()
                    }
                    if let price = displayPrice {
                        Text(formatPriceTg(price))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(oldPrice != nil ? Color.savingsGreen : Color.appForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .allowsTightening(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text(smartTitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.appForeground.opacity(0.86))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 34, alignment: .top)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().overlay(Color.appBorder)
            StoreGrid(slots: slots, bestId: bestSlot?.id, linkedCount: product.linkedStoresCount)
                .frame(height: 86)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)

            if cartCount > 0 {
                HStack(spacing: 0) {
                    Button(action: { onRemove?() }) {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 40)
                    }
                    Text("\(cartCount)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                    Button(action: { onAdd?() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 44, height: 40)
                    }
                }
                .foregroundStyle(Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.appPrimary.opacity(0.10))
            } else {
                Button(action: { onAdd?() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Добавить")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.appPrimary.opacity(0.10))
                }
            }
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appBorder.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.035), radius: 7, x: 0, y: 3)
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
            HStack(spacing: 6) {
                if let count = linkedCount, count > 0 {
                    Image(systemName: "storefront")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                    Text("\(count) \(storesWord(count))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 3) {
                ForEach(0..<slots.count, id: \.self) { i in
                    storeRow(slots[i])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func storeRow(_ slot: StoreSlot) -> some View {
        let isBest = slot.id == bestId
        HStack(spacing: 5) {
            StoreLogoView(url: slot.logoURL, slug: slot.chainSlug, source: slot.storeSource, size: 20)
                .opacity(slot.inStock ? 1.0 : 0.4)
                .frame(width: 22, height: 22)

            Text(formatCardStoreName(slug: slot.chainSlug, fallback: slot.chainName))
                .font(.system(size: 10, weight: isBest ? .bold : .semibold))
                .foregroundStyle(slot.inStock ? Color.appForeground.opacity(0.72) : Color.appMuted.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isBest {
                Text("MIN")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.appPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }

            Text(formatPriceTg(slot.price))
                .font(.system(size: 12, weight: isBest ? .bold : .regular))
                .foregroundStyle(isBest ? Color.appPrimary : Color.appMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .layoutPriority(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 23)
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
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.discountRed, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
        .shadow(color: Color.discountRed.opacity(0.28), radius: 4, x: 0, y: 2)
    }
}

private func storesWord(_ n: Int) -> String {
    let m10 = n % 10, m100 = n % 100
    if m100 >= 11 && m100 <= 19 { return "магазинов" }
    if m10 == 1 { return "магазин" }
    if m10 >= 2 && m10 <= 4 { return "магазина" }
    return "магазинов"
}

private func formatCardStoreName(slug: String?, fallback raw: String) -> String {
    let key = (slug ?? raw).lowercased().replacingOccurrences(of: " ", with: "")
    switch key {
    case "mgo", "magnumgo":              return "MagnumGO"
    case "airbafresh", "airba":          return "Airba"
    case "arbuz", "arbuz.kz", "arbuzkz": return "Arbuz"
    case "small":                        return "SMALL"
    case "galmart":                      return "Galmart"
    case "toimart":                      return "Toimart"
    case "wolt":                         return "SMALL"
    case "kaspi", "kaspimart":           return "Kaspi"
    default:
        if key.contains("magnum") { return "MagnumGO" }
        if key.contains("airba") { return "Airba" }
        if key.contains("arbuz") { return "Arbuz" }
        if key.contains("galmart") { return "Galmart" }
        if key.contains("toimart") { return "Toimart" }
        if key.contains("small") { return "SMALL" }
        if key.contains("kaspi") { return "Kaspi" }
        return raw
    }
}
