import SwiftUI
import Kingfisher

// Unified display model — merges StorePrice (list endpoints) and PriceRangeStore (detail endpoint)
private struct StoreSlot {
    let id: Int
    let chainName: String
    let storeSource: String
    let logoURL: URL?
    let price: Double
    let previousPrice: Double?
    let inStock: Bool
}

struct ProductCard: View, Equatable {
    let product: Product
    var onAdd: (() -> Void)? = nil

    // Equatable — SwiftUI пропускает re-render когда uuid и цена не изменились.
    // Без этого карточка пересобиралась на любой @Published из EnvironmentObject
    // (toastMessage, refreshCount, favourites…), что давало стуттеры на скролле.
    static func == (lhs: ProductCard, rhs: ProductCard) -> Bool {
        lhs.product.uuid == rhs.product.uuid &&
        lhs.product.cheapestPrice == rhs.product.cheapestPrice &&
        lhs.product.priceRange?.min == rhs.product.priceRange?.min &&
        lhs.product.stores?.count == rhs.product.stores?.count
    }

    private var slots: [StoreSlot] {
        // Prefer stores[] (list endpoints). Fall back to priceRange.stores (detail endpoint).
        if let s = product.stores, !s.isEmpty {
            return Array(s.prefix(3)).map {
                StoreSlot(id: $0.storeId, chainName: $0.chainName, storeSource: $0.storeSource,
                          logoURL: $0.logoURL, price: $0.price, previousPrice: $0.previousPrice, inStock: $0.inStock)
            }
        }
        if let s = product.priceRange?.stores, !s.isEmpty {
            return Array(s.prefix(3)).map {
                StoreSlot(id: $0.chainId, chainName: $0.chainName, storeSource: $0.storeSource,
                          logoURL: $0.logoURL, price: $0.price, previousPrice: $0.previousPrice, inStock: $0.inStock)
            }
        }
        return []
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
                if let pct = discountPercent {
                    DiscountChip(percent: pct).padding(8)
                }
            }

            // Price + name
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let price = displayPrice {
                        Text("\(Int(price)) ₸")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(oldPrice != nil ? Color.savingsGreen : Color.appForeground)
                    }
                    if let prev = oldPrice {
                        Text("\(Int(prev)) ₸")
                            .font(.system(size: 11))
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

            // Store comparison grid — 3 cols, horizontal
            Divider().overlay(Color.appBorder)
            StoreGrid(slots: slots, bestId: bestSlot?.id, linkedCount: product.linkedStoresCount)
                .frame(height: 64)
                .padding(.horizontal, 8)

            // Cart button — shows price, not generic text
            Button(action: { onAdd?() }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    if let price = displayPrice {
                        Text("\(Int(price)) ₸")
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
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appPrimary.opacity(0.18), lineWidth: 1))
        .compositingGroup() // схлопываем layer — тень рисуется один раз, не каждый кадр
        .neumorphicCard(radius: 16)
    }
}

// MARK: - 3-column store comparison grid

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
            // 1–3 stores — horizontal grid (same layout for all counts)
            HStack(alignment: .center, spacing: 0) {
                ForEach(0..<slots.count, id: \.self) { i in
                    let slot = slots[i]
                    let isBest = slot.id == bestId
                    VStack(spacing: 3) {
                        StoreLogoView(url: slot.logoURL, source: slot.storeSource, size: 22)
                            .opacity(slot.inStock ? 1.0 : 0.4)
                        Text("\(Int(slot.price)) ₸")
                            .font(.system(size: 10, weight: isBest ? .bold : .regular))
                            .foregroundStyle(isBest ? Color.appPrimary : Color.appMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if isBest {
                            Text("MIN")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(Color.appPrimary)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.appPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                        } else {
                            Color.clear.frame(height: 13)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
