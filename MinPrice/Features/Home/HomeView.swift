import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct HomeView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var favStores = FavoriteStoresStore.shared
    @State private var showCitySelector = false
    @State private var showAbout = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero — фильтр по магазинам. Кружки кликаются, выбор хранится локально,
                    // и автоматически прилипает ко всем product-запросам (через FavoriteStoresStore).
                    StoresFilterBar()
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .onChange(of: favStores.selectedIds) { _ in
                            // Перезагружаем главную при изменении набора магазинов —
                            // деалы/скидки фильтруются на бэке по chain_ids.
                            Task { await vm.load(cityId: cityStore.selectedCityId) }
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

                        if !vm.bestDeals.isEmpty {
                            SectionHeader(title: "Выгодные предложения",
                                          count: vm.bestDeals.count,
                                          eyebrow: "Сейчас выгодно",
                                          accent: Color.discountRed)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.bestDeals) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCardWrapper(product: product)
                                    }
                                    .buttonStyle(.pressScale)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        if !vm.priceDrops.isEmpty {
                            SectionHeader(title: "Снижение цен",
                                          count: vm.priceDrops.count,
                                          eyebrow: "Цены полетели вниз",
                                          accent: Color.savingsGreen)
                                .padding(.horizontal, 16)
                                .padding(.top, 28)
                                .padding(.bottom, 14)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.priceDrops) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCardWrapper(product: product)
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
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isDarkMode.toggle() }
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(isDarkMode ? Color.appPrimary : Color.appMuted)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Button { showAbout = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.appMuted)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
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
            .sheet(isPresented: $showAbout) {
                AboutView()
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

/// Drinkit-style section header:
/// — крошечный UPPERCASE eyebrow (10pt, kerning 1.6) акцентным цветом
/// — массивный title 26pt black rounded с минус-кернингом
/// — точка-флориш в конце акцентным цветом ("Выгодные предложения.")
/// — счётчик inline после точки, slightly muted accent цвета
private struct SectionHeader: View {
    let title: String
    let count: Int?
    var eyebrow: String? = nil
    var accent: Color = .appPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .kerning(1.6)
                    .foregroundStyle(accent)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .kerning(-0.6)
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(".")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
                if let count {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(accent.opacity(0.7))
                        .padding(.leading, 2)
                }
                Spacer(minLength: 0)
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

