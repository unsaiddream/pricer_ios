import SwiftUI
import Kingfisher

struct ProductCard: View {
    let product: Product
    var onAdd: (() -> Void)? = nil

    private var bestStore: StorePrice? {
        product.stores?
            .filter { $0.inStock }
            .min(by: { $0.price < $1.price })
            ?? product.stores?.first
    }

    private var discountPercent: Int? {
        guard let best = bestStore,
              let prev = best.previousPrice, prev > best.price else { return nil }
        let pct = Int(((prev - best.price) / prev) * 100)
        return pct > 0 ? pct : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Фото с градиентом
            ZStack {
                LinearGradient(
                    colors: [Color.appPrimary.opacity(0.14), Color.appCard],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                KFImage(product.coverURL)
                    .placeholder {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(Color.appMuted.opacity(0.3))
                    }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .frame(height: 140)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            // Стикер скидки — поверх clip, чуть выходит за угол
            .overlay(alignment: .topTrailing) {
                if let pct = discountPercent {
                    DiscountSticker(percent: pct)
                        .offset(x: 6, y: -6)
                }
            }

            // MARK: Цена + название
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let price = bestStore?.price {
                        Text("\(Int(price)) ₸")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.appForeground)
                    }
                    if let prev = bestStore?.previousPrice,
                       let cur = bestStore?.price, prev > cur {
                        Text("\(Int(prev)) ₸")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.appMuted)
                            .strikethrough()
                    }
                }
                .frame(height: 24, alignment: .bottom)

                Text(product.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appForeground.opacity(0.85))
                    .lineLimit(2)
                    .frame(height: 38, alignment: .top)

            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // MARK: Магазины
            if let stores = product.stores {
                VStack(spacing: 0) {
                    Divider().overlay(Color.appBorder)
                    VStack(spacing: 2) {
                        ForEach(stores.prefix(3)) { store in
                            StoreRow(store: store, isBest: store.storeId == bestStore?.storeId)
                        }
                        ForEach(0..<max(0, 3 - stores.count), id: \.self) { _ in
                            Color.clear.frame(height: 18)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, stores.count > 3 ? 2 : 6)

                    if stores.count > 3 {
                        Text("и ещё \(stores.count - 3) \(moreStoresText(stores.count - 3))")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 5)
                    }
                }
            }

            // MARK: Кнопка
            Divider().overlay(Color.appBorder)
            Button(action: { onAdd?() }) {
                HStack(spacing: 5) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("В корзину")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .padding(.horizontal, 10)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }

}

private func moreStoresText(_ n: Int) -> String {
    let m10 = n % 10, m100 = n % 100
    if m100 >= 11 && m100 <= 19 { return "магазинов" }
    if m10 == 1 { return "магазин" }
    if m10 >= 2 && m10 <= 4 { return "магазина" }
    return "магазинов"
}

// MARK: - Discount sticker

private struct DiscountSticker: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.discountRed)
                .shadow(color: Color.discountRed.opacity(0.4), radius: 6, x: 0, y: 3)
            VStack(spacing: -2) {
                Text("−\(percent)%")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 54, height: 54)
    }
}

// MARK: - Store row

private struct StoreRow: View {
    let store: StorePrice
    let isBest: Bool

    var body: some View {
        HStack(spacing: 5) {
            StoreLogoView(url: store.logoURL, source: store.storeSource, size: 18)

            Text(store.chainName)
                .font(.system(size: 11))
                .foregroundStyle(Color.appMuted)
                .lineLimit(1)

            if isBest {
                Text("min")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(Color.appPrimary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
            }

            Spacer()

            if let prev = store.previousPrice, prev > store.price {
                Text("\(Int(prev)) ₸")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appMuted.opacity(0.6))
                    .strikethrough()
            }

            Text("\(Int(store.price)) ₸")
                .font(.system(size: 11, weight: isBest ? .semibold : .regular))
                .foregroundStyle(isBest ? Color.appForeground : Color.appMuted)
        }
        .frame(height: 18)
        .opacity(store.inStock ? 1 : 0.5)
    }
}
