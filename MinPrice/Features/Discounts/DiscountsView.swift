import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct DiscountsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // Заголовок + статы (счётчик скидок + средняя)
                VStack(alignment: .leading, spacing: 6) {
                    BrandTitle(text: "Скидки")
                    DiscountsStatsRow(products: vm.products)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Hero — топовая скидка дня (самый большой % в первой странице)
                if let top = bestDiscountProduct, !vm.isLoading {
                    NavigationLink(value: top.uuid) {
                        HotDealBanner(product: top)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }
                    .buttonStyle(.pressScale)
                }

                if vm.isLoading && vm.products.isEmpty {
                    SkeletonCardGrid()
                        .padding(.vertical, 12)
                } else if vm.products.isEmpty && !vm.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.appMuted.opacity(0.4))
                        Text("Нет данных")
                            .font(.jb(15))
                            .foregroundStyle(Color.appMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(vm.products) { product in
                            NavigationLink(value: product.uuid) {
                                ProductCardWrapper(product: product)
                            }
                            .buttonStyle(.pressScale)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Sentinel — отдельный view внизу списка. Он получает .onAppear
                    // только когда виден, причём ровно один. Это надёжнее чем вешать
                    // onAppear на каждую карточку (та фигачит на каждом recycle).
                    if !vm.products.isEmpty {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await vm.load(cityId: cityStore.selectedCityId, append: true) }
                            }
                    }

                    if vm.isLoading {
                        ProgressView().tint(Color.appPrimary).padding()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .refreshable {
                await vm.refresh(cityId: cityStore.selectedCityId)
            }
        }
        .task {
            await vm.load(cityId: cityStore.selectedCityId)
        }
        .onChange(of: cityStore.selectedCityId) { newId in
            Task { await vm.refresh(cityId: newId) }
        }
    }

    private var bestDiscountProduct: Product? {
        // Берём первый товар (бэк уже отсортировал по discount_percent desc).
        // Это становится hot-deal баннером в шапке.
        vm.products.first
    }
}

// MARK: - Stats row (счётчик скидок + средняя)

private struct DiscountsStatsRow: View {
    let products: [Product]

    private var avgDiscount: Int {
        // Берём процент по priceRange.savingsPercent (готовый агрегат с бэка)
        // или из best store. Бэк уже шлёт скидочные товары — savingsPercent должен быть.
        let percents: [Double] = products.compactMap { p in
            if let pct = p.priceRange?.savingsPercent, pct > 0 {
                return pct
            }
            if let stores = p.stores,
               let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
               let prev = best.previousPrice, prev > best.price {
                return ((prev - best.price) / prev) * 100
            }
            return nil
        }
        guard !percents.isEmpty else { return 0 }
        return Int(percents.reduce(0, +) / Double(percents.count))
    }

    var body: some View {
        HStack(spacing: 8) {
            if !products.isEmpty {
                StatPill(icon: "tag.fill", text: "\(products.count) скидок", tint: Color.discountRed)
                if avgDiscount > 0 {
                    StatPill(icon: "chart.line.downtrend.xyaxis", text: "средняя -\(avgDiscount)%", tint: Color.savingsGreen)
                }
            } else {
                Text("Лучшие предложения дня")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
        }
    }
}

private struct StatPill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 0.6))
    }
}

// MARK: - Hot deal banner — топовый товар дня

private struct HotDealBanner: View {
    let product: Product

    private var discountPercent: Int? {
        if let pct = product.priceRange?.savingsPercent, pct > 0 { return Int(pct) }
        return nil
    }

    private var oldPrice: Double? {
        let stores = product.stores ?? []
        guard let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
              let prev = best.previousPrice, prev > best.price else { return nil }
        return prev
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .black))
                    Text("ТОП СКИДКА")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .kerning(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.white.opacity(0.22), in: Capsule())

                Text(product.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let cheapest = product.cheapestPrice {
                        Text(formatPriceTg(cheapest))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    if let prev = oldPrice {
                        Text(formatPriceTg(prev))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                            .strikethrough()
                    }
                    if let pct = discountPercent {
                        Text("-\(pct)%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Color.discountRed)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.white, in: Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color.discountRed, Color.discountRedDeep, Color.appPrimary.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .shadow(color: Color.discountRed.opacity(0.30), radius: 10, x: 0, y: 5)
    }
}

