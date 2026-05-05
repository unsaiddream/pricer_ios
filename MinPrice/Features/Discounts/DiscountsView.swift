import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct DiscountsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // Заголовок + лёгкая полоска статов под ним (счётчик + средняя)
                VStack(alignment: .leading, spacing: 6) {
                    BrandTitle(text: "Скидки")
                    if !vm.products.isEmpty {
                        HStack(spacing: 6) {
                            DiscountStatPill(icon: "tag.fill",
                                             text: "\(vm.products.count) \(discountsWord(vm.products.count))",
                                             tint: Color.discountRed)
                            if avgDiscount > 0 {
                                DiscountStatPill(icon: "chart.line.downtrend.xyaxis",
                                                 text: "средняя -\(avgDiscount)%",
                                                 tint: Color.savingsGreen)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

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
                        PaginationLoader()
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

    /// Среднюю скидку считаем по priceRange.savingsPercent или previousPrice/price.
    private var avgDiscount: Int {
        let percents: [Double] = vm.products.compactMap { p in
            if let pct = p.priceRange?.savingsPercent, pct > 0 { return pct }
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

    private func discountsWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "скидок" }
        if m10 == 1 { return "скидка" }
        if m10 >= 2 && m10 <= 4 { return "скидки" }
        return "скидок"
    }
}

private struct DiscountStatPill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
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

