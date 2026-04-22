import SwiftUI
import Kingfisher

struct ProductRow: View {
    let product: Product

    private var bestPrice: Double? {
        product.stores?.filter { $0.inStock }.min(by: { $0.price < $1.price })?.price
            ?? product.cheapestPrice
    }

    private var oldPrice: Double? {
        guard let best = product.stores?.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
              let prev = best.previousPrice, prev > best.price else { return nil }
        return prev
    }

    var body: some View {
        HStack(spacing: 12) {
            KFImage(product.coverURL)
                .placeholder {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appBackground)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)

                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let price = bestPrice {
                    Text("\(Int(price)) ₸")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appForeground)
                }
                if let prev = oldPrice {
                    Text("\(Int(prev)) ₸")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                        .strikethrough()
                }
            }
        }
        .padding(.vertical, 6)
    }
}
