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

    private var discountPercent: Int? {
        guard let best = product.stores?.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
              let prev = best.previousPrice, prev > best.price else { return nil }
        let pct = Int(((prev - best.price) / prev) * 100)
        return pct > 0 ? pct : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                KFImage(product.coverURL)
                    .placeholder { RoundedRectangle(cornerRadius: 10).fill(Color.appBackground) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let pct = discountPercent {
                    Text("−\(pct)%")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.discountRed, in: RoundedRectangle(cornerRadius: 4))
                        .offset(x: -2, y: -2)
                }
            }

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

                if let count = product.stores?.count, count > 0 {
                    Text("\(count) магазинов")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let price = bestPrice {
                    Text("\(Int(price)) ₸")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.savingsGreen)
                }
                if let prev = oldPrice {
                    Text("\(Int(prev)) ₸")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                        .strikethrough()
                }
            }
        }
        .padding(.vertical, 8)
    }
}
