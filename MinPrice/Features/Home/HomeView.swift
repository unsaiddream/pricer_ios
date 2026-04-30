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

                    // Hero — корзина по каталогу дня (с ротацией).
                    // Отключаемо через RemoteConfig.features.storeBasketChart=false
                    // на случай если бэкенд просядет или мы захотим тихо отключить
                    // фичу всем пользователям без релиза.
                    // Приоритет — готовый агрегат с бэка (vm.basketSummary).
                    // Если эндпоинт не задеплоен / упал, vm падает на legacy-путь
                    // с products[] и клиентским precompute.
                    if (vm.basketSummary != nil || !vm.basketProducts.isEmpty),
                       ConfigSnapshot.isEnabled(.storeBasketChart) {
                        StoreBasketChart(
                            category: vm.basketCategory,
                            summary: vm.basketSummary,
                            products: vm.basketProducts
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }

                    if vm.isLoading {
                        SkeletonGrid()
                    } else if vm.bestDeals.isEmpty && vm.priceDrops.isEmpty
                              && vm.basketSummary == nil && vm.basketProducts.isEmpty {
                        // Полный пустой экран после загрузки = сетевой/серверный сбой.
                        // Показываем ErrorStateView с retry, иначе пользователь видит белый.
                        ErrorStateView(
                            vm.errorMessage != nil ? .networkError : .serverError,
                            retry: { Task { await vm.load(cityId: cityStore.selectedCityId) } }
                        )
                        .frame(minHeight: 400)
                    } else {
                        if let error = vm.errorMessage {
                            ErrorBanner(message: error) {
                                Task { await vm.load(cityId: cityStore.selectedCityId) }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }

                        if !vm.categories.isEmpty {
                            CategoryStrip(
                                categories: vm.categories,
                                selectedId: vm.basketCategory?.id,
                                onSelectAll: {
                                    Task { await vm.selectAllCategories(cityId: cityStore.selectedCityId) }
                                }
                            ) { cat in
                                Task { await vm.selectBasketCategory(cat, cityId: cityStore.selectedCityId) }
                            }
                            .padding(.bottom, 16)
                        }

                        if !vm.bestDeals.isEmpty {
                            SectionHeader(title: "Выгодные предложения", count: vm.bestDeals.count, accent: Color.discountRed)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.bestDeals) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCard(product: product) {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        }.equatable()
                                    }
                                    .buttonStyle(.pressScale)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        if !vm.priceDrops.isEmpty {
                            SectionHeader(title: "Снижение цен", count: nil, accent: Color.savingsGreen)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.priceDrops) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCard(product: product) {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        }.equatable()
                                    }
                                    .buttonStyle(.pressScale)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 180)
            }
            .background(
                // Фон не трогаем во время скролла — drawingGroup растеризует
                // градиент в один слой, ОС не пересчитывает его кадрово.
                LinearGradient.homeBackground(isDark: isDarkMode)
                    .drawingGroup()
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: isDarkMode)
            )
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
                    HStack(spacing: 6) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                        Text("minprice.kz")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .kerning(-0.2)
                            .foregroundStyle(LinearGradient.brandPrimary)
                    }
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
    let selectedId: Int?
    let onSelectAll: () -> Void
    let onSelect: (Category) -> Void

    private var isAllSelected: Bool { selectedId == nil }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Кнопка «Все» — общий график по всем товарам
                Button {
                    onSelectAll()
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(
                                    isAllSelected
                                        ? AnyShapeStyle(LinearGradient.brandPrimary)
                                        : AnyShapeStyle(Color.appPrimary.opacity(0.18))
                                )
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(isAllSelected ? .white : Color.appPrimary)
                        }
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().stroke(
                                isAllSelected ? Color.appPrimary.opacity(0.6) : Color.appPrimary.opacity(0.30),
                                lineWidth: isAllSelected ? 1.5 : 1
                            )
                        )
                        .shadow(
                            color: isAllSelected ? Color.appPrimary.opacity(0.40) : .clear,
                            radius: 8, x: 0, y: 3
                        )

                        Text("Все")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                isAllSelected
                                    ? AnyShapeStyle(LinearGradient.brandPrimary)
                                    : AnyShapeStyle(Color.appPrimary)
                            )
                            .lineLimit(1)
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.pressScale)

                ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                    let color = categoryChipPalette[idx % categoryChipPalette.count]
                    let isSelected = (selectedId == cat.id)

                    Button {
                        onSelect(cat)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(
                                        isSelected
                                            ? AnyShapeStyle(LinearGradient.brandPrimary)
                                            : AnyShapeStyle(color.opacity(0.18))
                                    )
                                Text(cat.emoji ?? "🛍️")
                                    .font(.system(size: 24))
                            }
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle().stroke(
                                    isSelected ? Color.appPrimary.opacity(0.6) : color.opacity(0.3),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                            )
                            .shadow(
                                color: isSelected ? Color.appPrimary.opacity(0.40) : .clear,
                                radius: 8, x: 0, y: 3
                            )

                            Text(cat.name)
                                .font(.system(size: 10, weight: isSelected ? .heavy : .medium, design: .rounded))
                                .foregroundStyle(
                                    isSelected
                                        ? AnyShapeStyle(LinearGradient.brandPrimary)
                                        : AnyShapeStyle(Color.appMuted)
                                )
                                .lineLimit(1)
                                .frame(width: 60)
                        }
                    }
                    .buttonStyle(.pressScale)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }
}

private struct HeroBanner: View {
    private let stores: [String] = ["store_magnum", "store_arbuz", "store_airba_fresh", "store_small"]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Сравнение цен")
                    .font(.jb(15, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Text("Минимальная цена в 4 магазинах")
                    .font(.jb(12))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
            HStack(spacing: -8) {
                ForEach(stores, id: \.self) { asset in
                    ZStack {
                        Circle().fill(.white)
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appPrimary.opacity(0.15), lineWidth: 1))
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int?
    var accent: Color = .appPrimary

    private var titleGradient: LinearGradient { .brandPrimary }

    var body: some View {
        HStack(spacing: 10) {
            // Accent bar — мини-градиент в тон акценту
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.95), accent.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 20)
                .shadow(color: accent.opacity(0.5), radius: 4, x: 0, y: 0)

            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .kerning(0.3)
                .foregroundStyle(titleGradient)
                .shadow(color: Color.appPrimary.opacity(0.20), radius: 6, x: 0, y: 0)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 2.5)
                    .background {
                        ZStack {
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            LinearGradient(
                                colors: [.white.opacity(0.30), .clear],
                                startPoint: .top, endPoint: .center
                            )
                        }
                        .clipShape(Capsule())
                    }
                    .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
                    .shadow(color: accent.opacity(0.40), radius: 5, x: 0, y: 2)
                    .fixedSize()
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

