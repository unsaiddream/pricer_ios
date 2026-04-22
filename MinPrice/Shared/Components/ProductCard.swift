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

                Text(product.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appForeground.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 36)

                if let storeCount = product.stores?.count, storeCount > 0 {
                    Text("\(storeCount) \(storeWord(storeCount))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

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

    private func storeWord(_ n: Int) -> String {
        switch n % 10 {
        case 1 where n % 100 != 11: return "магазин"
        case 2...4 where !(11...14).contains(n % 100): return "магазина"
        default: return "магазинов"
        }
    }
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
