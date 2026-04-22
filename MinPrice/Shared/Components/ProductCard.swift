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

    private var savingsAmount: Int? {
        guard let best = bestStore,
              let prev = best.previousPrice, prev > best.price else { return nil }
        return Int(prev - best.price)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Фото
            ZStack(alignment: .topLeading) {
                KFImage(product.coverURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.appBackground)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(Color.appMuted.opacity(0.4))
                            )
                    }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 140)
                    .frame(height: 140)
                    .background(Color.appBackground)
                    .clipped()

                // Бейджи скидки
                VStack(alignment: .leading, spacing: 3) {
                    if let pct = discountPercent {
                        BadgeView(text: "−\(pct)%", color: .discountRed)
                    }
                    if let savings = savingsAmount {
                        BadgeView(text: "−\(savings) ₸", color: .savingsGreen)
                    }
                }
                .padding(6)
            }

            // MARK: Цена + название
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if let price = bestStore?.price {
                        Text("\(Int(price)) ₸")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appForeground)
                    }
                    if let prev = bestStore?.previousPrice, let cur = bestStore?.price, prev > cur {
                        Text("\(Int(prev)) ₸")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appMuted)
                            .strikethrough()
                    }
                }

                Text(product.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 34)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // MARK: Магазины
            if let stores = product.stores {
                VStack(spacing: 0) {
                    Divider().overlay(Color.appBorder)
                    VStack(spacing: 2) {
                        ForEach(stores.prefix(3)) { store in
                            StoreRow(store: store, isBest: store.storeId == bestStore?.storeId)
                        }
                        // Пустые строки для выравнивания высоты
                        ForEach(0..<max(0, 3 - stores.count), id: \.self) { _ in
                            Color.clear.frame(height: 18)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }

            // MARK: Кнопка добавить
            Divider().overlay(Color.appBorder)
            Button(action: { onAdd?() }) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Добавить")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .padding(.horizontal, 10)
        }
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Subviews

private struct BadgeView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
    }
}

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
