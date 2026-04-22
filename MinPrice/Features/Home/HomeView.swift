import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct HomeView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = HomeViewModel()
    @State private var showCitySelector = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero баннер
                    HeroBanner()
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    // Виджет экономии
                    SavingsBanner(cart: cartStore.cart)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 16)

                    if vm.isLoading {
                        SkeletonGrid()
                    } else {
                        if let error = vm.errorMessage {
                            ErrorBanner(message: error) {
                                Task { await vm.load(cityId: cityStore.selectedCityId) }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 16)
                        }

                        if !vm.categories.isEmpty {
                            CategoryStrip(categories: vm.categories)
                                .padding(.bottom, 16)
                        }

                        if !vm.bestDeals.isEmpty {
                            SectionHeader(title: "🔥 Выгодные предложения", count: vm.bestDeals.count)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.bestDeals) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCard(product: product) {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                        }

                        if !vm.priceDrops.isEmpty {
                            SectionHeader(title: "📉 Снижение цен", count: nil)
                                .padding(.horizontal, 14)
                                .padding(.top, 24)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.priceDrops) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCard(product: product) {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle("minprice.kz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isDarkMode.toggle() }
                    } label: {
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isDarkMode ? Color.appPrimary : Color.appMuted)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                ToolbarItem(placement: .principal) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 28)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCitySelector = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                            Text(cityStore.selectedCity?.name ?? "Алматы")
                                .font(.jb(13))
                        }
                        .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .sheet(isPresented: $showCitySelector) {
                CitySelectorSheet(isPresented: $showCitySelector)
            }
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .refreshable {
                await vm.load(cityId: cityStore.selectedCityId)
            }
        }
        .task {
            await vm.load(cityId: cityStore.selectedCityId)
        }
        .onChange(of: cityStore.selectedCityId) { newId in
            Task { await vm.load(cityId: newId) }
        }
    }
}

// MARK: - Subviews

private let categoryChipPalette: [Color] = [
    .red, .orange, .green, .blue, .purple,
    .pink, .teal, .indigo, .yellow, .mint, .cyan, .brown
]

private struct CategoryStrip: View {
    let categories: [Category]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                    let color = categoryChipPalette[idx % categoryChipPalette.count]
                    VStack(spacing: 4) {
                        Text(cat.emoji ?? "🛍️")
                            .font(.system(size: 24))
                            .frame(width: 52, height: 52)
                            .background(color.opacity(0.15), in: Circle())
                            .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
                        Text(cat.name)
                            .font(.jb(10, weight: .medium))
                            .foregroundStyle(Color.appMuted)
                            .lineLimit(1)
                            .frame(width: 60)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }
}

private struct HeroBanner: View {
    private let stores: [(asset: String, name: String)] = [
        ("store_magnum", "Magnum"),
        ("store_arbuz", "Arbuz"),
        ("store_airba_fresh", "Airba"),
        ("store_small", "Small"),
    ]

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Сравнение цен на продукты")
                    .font(.jb(14, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Text("Минимальная цена в 4 магазинах")
                    .font(.jb(12))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(stores, id: \.asset) { store in
                    Image(store.asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.appBorder, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int?

    var body: some View {
        HStack {
            Text(title)
                .font(.jb(17, weight: .bold))
                .foregroundStyle(Color.appForeground)
            Spacer()
            if let count {
                Text("\(count) товаров")
                    .font(.jb(13))
                    .foregroundStyle(Color.appMuted)
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("Не удалось загрузить данные")
                .font(.subheadline.bold())
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
            Button("Повторить", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(Color.appPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct SkeletonGrid: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appBorder)
                .frame(width: 180, height: 18)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appBorder.opacity(0.5))
                        .frame(height: 300)
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

// MARK: - Savings Banner

private struct SavingsBanner: View {
    let cart: Cart?

    // Сколько сэкономил пользователь на товарах в корзине
    private var totalSavings: Int {
        guard let items = cart?.items else { return 0 }
        return items.compactMap { item -> Int? in
            guard let best = item.product.stores?
                    .filter({ $0.inStock })
                    .min(by: { $0.price < $1.price }),
                  let prev = best.previousPrice, prev > best.price
            else { return nil }
            return Int((prev - best.price) * Double(item.quantity))
        }.reduce(0, +)
    }

    private var purchaseCount: Int { cart?.itemsCount ?? 0 }

    private var currentMonth: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "LLLL"
        return fmt.string(from: Date()).uppercased()
    }

    private let storeAssets: [(asset: String, color: Color)] = [
        ("store_magnum",      Color(red: 0.90, green: 0.21, blue: 0.21)),
        ("store_arbuz",       Color(red: 0.26, green: 0.63, blue: 0.28)),
        ("store_airba_fresh", Color.white),
        ("store_small",       Color.white),
    ]

    var body: some View {
        ZStack(alignment: .leading) {
            // Тёмный фон
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.22))

            // Декоративный blob справа
            GeometryReader { geo in
                Circle()
                    .fill(Color.appPrimary.opacity(0.25))
                    .frame(width: 130, height: 130)
                    .blur(radius: 28)
                    .offset(x: geo.size.width - 80, y: -20)
                Circle()
                    .fill(Color.appPrimary.opacity(0.10))
                    .frame(width: 80, height: 80)
                    .blur(radius: 16)
                    .offset(x: geo.size.width - 50, y: 50)
            }
            .clipped()

            // Контент
            VStack(alignment: .leading, spacing: 6) {
                Text("ВЫ СЭКОНОМИЛИ · \(currentMonth)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(1.2)

                if totalSavings > 0 {
                    Text("\(formattedNumber(totalSavings)) ₸")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                    Text("на \(purchaseCount) \(purchaseWord(purchaseCount)) в корзине")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                } else if purchaseCount > 0 {
                    Text("0 ₸")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                    Text("Все товары по честной цене")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text("0 ₸")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Добавляйте товары со скидкой")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 7) {
                    ForEach(storeAssets, id: \.asset) { item in
                        Image(item.asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .background(item.color, in: Circle())
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 2)
            }
            .padding(18)
        }
        .frame(height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func purchaseWord(_ n: Int) -> String {
        switch n % 10 {
        case 1 where n % 100 != 11: return "покупке"
        case 2...4 where !(11...14).contains(n % 100): return "покупках"
        default: return "покупках"
        }
    }

    private func formattedNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
