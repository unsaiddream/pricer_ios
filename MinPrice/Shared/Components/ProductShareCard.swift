import SwiftUI
import UIKit

// MARK: - Share card view (rendered to image via ImageRenderer)

struct ProductShareCard: View {
    let product: Product
    let productImage: UIImage?

    private var stores: [PriceRangeStore] { product.priceRange?.stores ?? [] }
    private var minStore: PriceRangeStore? { stores.min(by: { $0.price < $1.price }) }
    private var maxStore: PriceRangeStore? { stores.max(by: { $0.price < $1.price }) }
    private var maxPrice: Double { stores.map(\.price).max() ?? 1 }

    private var savingsPct: Int? {
        guard let min = minStore?.price, let max = maxStore?.price, max > min else { return nil }
        let pct = Int(((max - min) / max) * 100)
        return pct >= 1 ? pct : nil
    }

    private var brandPrimary: LinearGradient {
        LinearGradient(
            colors: [
                Color.appPrimaryLight,
                Color.appPrimary,
                Color.appPrimaryDeep,
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var greenSoft: Color { Color(red: 0.35, green: 0.85, blue: 0.55) }
    private var savingsGreen: Color { Color.savingsGreen }
    private var greenDeep: Color { Color(red: 0.04, green: 0.55, blue: 0.30) }
    private var discountRed: Color { Color(red: 0.95, green: 0.30, blue: 0.40) }

    var body: some View {
        VStack(spacing: 0) {
            // Header — тёмный premium с glow
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.10, blue: 0.16),
                        Color(red: 0.06, green: 0.18, blue: 0.26),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appPrimary.opacity(0.45), .clear],
                                center: .center, startRadius: 0, endRadius: 90
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(x: -40, y: -40)
                        .blur(radius: 12)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [savingsGreen.opacity(0.30), .clear],
                                center: .center, startRadius: 0, endRadius: 80
                            )
                        )
                        .frame(width: 140, height: 140)
                        .offset(x: geo.size.width - 80, y: geo.size.height - 60)
                        .blur(radius: 12)
                }

                HStack(spacing: 8) {
                    if let img = UIImage(named: "AppLogo") {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(height: 30)
                    }
                    Text("minprice.kz")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(brandPrimary)
                        .kerning(-0.2)
                    Spacer()
                    if let pct = savingsPct {
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
                                    colors: [discountRed.opacity(0.95), Color.discountRedDeep],
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
                        .shadow(color: discountRed.opacity(0.45), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 60)

            // Product image — с мягким радиальным свечением
            ZStack {
                Color.white
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appPrimary.opacity(0.10), .clear],
                                center: .center, startRadius: 0, endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .offset(x: geo.size.width / 2 - 110, y: 30)
                        .blur(radius: 6)
                }
                if let img = productImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .frame(height: 220)

            // Info section
            VStack(alignment: .leading, spacing: 16) {

                // Brand pill
                if let brand = product.brand, !brand.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(brand.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .kerning(1.2)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background {
                            ZStack {
                                brandPrimary
                                LinearGradient(
                                    colors: [.white.opacity(0.30), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            }
                            .clipShape(Capsule())
                        }
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                }

                // Title
                Text(product.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(white: 0.10))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Hero price block
                if let best = minStore {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(savingsGreen.opacity(0.85))
                                Text("ОТ")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .tracking(1.6)
                                    .foregroundStyle(savingsGreen.opacity(0.90))
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(formatPrice(best.price))")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [greenSoft, savingsGreen, greenDeep],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                Text("₸")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(savingsGreen.opacity(0.75))
                            }
                            .monospacedDigit()
                        }

                        Spacer()

                        // Магазин-победитель
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("дешевле всего в")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.gray)
                            HStack(spacing: 5) {
                                if let logoImg = storeLocalImage(source: best.storeSource) {
                                    Image(uiImage: logoImg)
                                        .resizable().scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                Text(brandLabel(best.storeSource))
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(Color(white: 0.15))
                            }
                        }
                    }
                }

                // Price bars
                if stores.count > 1 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimary.opacity(0.22), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Цены в магазинах")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .kerning(0.8)
                            .foregroundStyle(Color.gray)

                        ForEach(Array(stores.prefix(4).enumerated()), id: \.offset) { _, store in
                            let ratio = maxPrice > 0 ? store.price / maxPrice : 1
                            let isMin = store.price == minStore?.price
                            HStack(spacing: 8) {
                                HStack(spacing: 5) {
                                    if let logoImg = storeLocalImage(source: store.storeSource) {
                                        Image(uiImage: logoImg)
                                            .resizable().scaledToFit()
                                            .frame(width: 18, height: 18)
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                    Text(brandLabel(store.storeSource))
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color(white: 0.30))
                                        .lineLimit(1)
                                }
                                .frame(width: 100, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color(white: 0.93))
                                        Capsule()
                                            .fill(
                                                isMin
                                                    ? AnyShapeStyle(
                                                        LinearGradient(
                                                            colors: [greenSoft, savingsGreen, greenDeep],
                                                            startPoint: .leading, endPoint: .trailing
                                                        )
                                                      )
                                                    : AnyShapeStyle(
                                                        LinearGradient(
                                                            colors: [
                                                                storeColorFor(store.storeSource).opacity(0.85),
                                                                storeColorFor(store.storeSource).opacity(0.55),
                                                            ],
                                                            startPoint: .leading, endPoint: .trailing
                                                        )
                                                      )
                                            )
                                            .frame(width: geo.size.width * ratio)
                                    }
                                }
                                .frame(height: 8)

                                Text(formatPrice(store.price) + " ₸")
                                    .font(.system(size: 11, weight: isMin ? .black : .heavy, design: .rounded))
                                    .foregroundStyle(
                                        isMin
                                            ? AnyShapeStyle(
                                                LinearGradient(
                                                    colors: [savingsGreen, greenDeep],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                              )
                                            : AnyShapeStyle(Color(white: 0.40))
                                    )
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.appPrimary.opacity(0.30),
                            Color.appPrimary.opacity(0.10),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.appPrimary.opacity(0.18), radius: 22, x: 0, y: 12)
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .frame(width: 360)
    }

    private func formatPrice(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? String(Int(v))
    }
}

// MARK: - Helpers

private func storeLocalImage(source: String?) -> UIImage? {
    switch source?.lowercased() {
    case "mgo", "magnumgo":     return UIImage(named: "store_magnum")
    case "arbuz":               return UIImage(named: "store_arbuz")
    case "airbafresh", "airba": return UIImage(named: "store_airba_fresh")
    case "small", "wolt":       return UIImage(named: "store_small")
    default:                    return nil
    }
}

private func brandLabel(_ source: String?) -> String {
    switch source?.lowercased() {
    case "mgo", "magnumgo":     return "MagnumGO"
    case "arbuz":               return "Arbuz.kz"
    case "airbafresh", "airba": return "AirbaFresh"
    case "small", "wolt":       return "SMALL"
    default:                    return source ?? "—"
    }
}

private func storeColorFor(_ source: String?) -> Color {
    switch source?.lowercased() {
    case "mgo", "magnumgo":     return Color(red: 0.95, green: 0.30, blue: 0.30)
    case "arbuz":               return Color(red: 1.00, green: 0.55, blue: 0.20)
    case "airbafresh", "airba": return Color(red: 0.30, green: 0.65, blue: 1.00)
    case "small", "wolt":       return Color(red: 0.70, green: 0.45, blue: 1.00)
    default:                    return Color.appPrimaryLight
    }
}

// MARK: - Share helper

@MainActor
func makeProductShareImage(product: Product, productImage: UIImage? = nil) -> UIImage? {
    let card = ProductShareCard(product: product, productImage: productImage)
        .padding(28)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.94, blue: 0.99),
                    Color(red: 0.95, green: 0.98, blue: 1.00),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )

    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage
}
