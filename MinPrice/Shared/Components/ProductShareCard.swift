import SwiftUI
import UIKit

// MARK: - Share card view (rendered to image via ImageRenderer)

struct ProductShareCard: View {
    let product: Product
    let productImage: UIImage?

    private var stores: [PriceRangeStore] { product.priceRange?.stores ?? [] }
    private var minStore: PriceRangeStore? { stores.min(by: { $0.price < $1.price }) }
    private var maxPrice: Double { stores.map(\.price).max() ?? 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Header — gradient с логотипом
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.78, blue: 0.98), Color(red: 0.10, green: 0.55, blue: 0.88)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                HStack {
                    if let img = UIImage(named: "AppLogo") {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(height: 26)
                    }
                    Spacer()
                    Text("minprice.kz")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 52)

            // Product image
            ZStack {
                Color(red: 0.96, green: 0.97, blue: 0.99)
                if let img = productImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .frame(height: 200)

            // Info section
            VStack(alignment: .leading, spacing: 14) {

                // Name
                Text(product.title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(white: 0.1))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Min price + store
                if let best = minStore {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Лучшая цена")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.gray)
                            Text("\(Int(best.price)) ₸")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.10, green: 0.55, blue: 0.88))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("в магазине")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gray)
                            HStack(spacing: 6) {
                                if let logoImg = storeLocalImage(source: best.storeSource) {
                                    Image(uiImage: logoImg)
                                        .resizable().scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                Text(best.chainName)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color(white: 0.15))
                            }
                        }
                    }
                }

                // Price bars
                if stores.count > 1 {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Цены в магазинах")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.gray)

                        ForEach(stores.prefix(4), id: \.storeName) { store in
                            let ratio = maxPrice > 0 ? store.price / maxPrice : 1
                            let isMin = store.price == minStore?.price
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    if let logoImg = storeLocalImage(source: store.storeSource) {
                                        Image(uiImage: logoImg)
                                            .resizable().scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                    Text(store.chainName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color(white: 0.3))
                                        .lineLimit(1)
                                }
                                .frame(width: 88, alignment: .leading)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(isMin
                                              ? Color(red: 0.10, green: 0.55, blue: 0.88)
                                              : Color(white: 0.85))
                                        .frame(width: geo.size.width * ratio)
                                }
                                .frame(height: 10)

                                Text("\(Int(store.price)) ₸")
                                    .font(.system(size: 11, weight: isMin ? .bold : .regular, design: .monospaced))
                                    .foregroundStyle(isMin ? Color(red: 0.10, green: 0.55, blue: 0.88) : Color(white: 0.4))
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        .frame(width: 340)
    }
}

// MARK: - Store logo helper (sync, for ImageRenderer)

private func storeLocalImage(source: String?) -> UIImage? {
    switch source {
    case "mgo":        return UIImage(named: "store_magnum")
    case "arbuz":      return UIImage(named: "store_arbuz")
    case "airbafresh": return UIImage(named: "store_airba_fresh")
    case "wolt":       return UIImage(named: "store_small")
    default:           return nil
    }
}

// MARK: - Share helper

@MainActor
func makeProductShareImage(product: Product, productImage: UIImage? = nil) -> UIImage? {
    let card = ProductShareCard(product: product, productImage: productImage)
        .padding(24)
        .background(Color(red: 0.94, green: 0.97, blue: 1.0))

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage
}
