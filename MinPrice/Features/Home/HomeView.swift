import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct HomeView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = HomeViewModel()
    @ObservedObject private var favStores = FavoriteStoresStore.shared
    @State private var showCitySelector = false
    @State private var showAbout = false
    @State private var homeLoadTask: Task<Void, Never>?
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero — фильтр по магазинам. Кружки кликаются, выбор хранится локально,
                    // и автоматически прилипает ко всем product-запросам (через FavoriteStoresStore).
                    StoresFilterBar()
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .onChange(of: favStores.selectedIds) { _ in
                            scheduleHomeReload(cityId: cityStore.selectedCityId, debounce: true)
                        }

                    if vm.isLoading {
                        SkeletonGrid()
                    } else if vm.bestDeals.isEmpty && vm.priceDrops.isEmpty
                              && vm.basketSummary == nil && vm.basketProducts.isEmpty {
                        // Полный пустой экран после загрузки = сетевой/серверный сбой.
                        // Показываем ErrorStateView с retry, иначе пользователь видит белый.
                        ErrorStateView(
                            vm.errorMessage != nil ? .networkError : .serverError,
                            retry: { scheduleHomeReload(cityId: cityStore.selectedCityId) }
                        )
                        .frame(minHeight: 400)
                    } else {
                        if let error = vm.errorMessage {
                            ErrorBanner(message: error) {
                                scheduleHomeReload(cityId: cityStore.selectedCityId)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }

                        if !vm.bestDeals.isEmpty {
                            SectionHeader(
                                title: "Выгодные предложения",
                                count: vm.bestDealsTotal ?? vm.bestDeals.count,
                                icon: "flame.fill",
                                accent: Color.discountRed
                            )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.bestDeals) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCardWrapper(product: product)
                                    }
                                    .buttonStyle(.pressScale)
                                    .onAppear {
                                        guard product.uuid == vm.bestDeals.last?.uuid else { return }
                                        Task { await vm.loadMoreBestDeals(cityId: cityStore.selectedCityId) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if vm.isLoadingMoreBestDeals {
                                PaginationLoader()
                            }
                        }

                        if !vm.priceDrops.isEmpty {
                            SectionHeader(
                                title: "Снижение цен",
                                count: vm.priceDrops.count,
                                icon: "chart.line.downtrend.xyaxis",
                                accent: Color.savingsGreen
                            )
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                                .padding(.bottom, 10)

                            LazyVGrid(columns: gridColumns, spacing: 10) {
                                ForEach(vm.priceDrops) { product in
                                    NavigationLink(value: product.uuid) {
                                        ProductCardWrapper(product: product)
                                    }
                                    .buttonStyle(.pressScale)
                                    .onAppear {
                                        guard product.uuid == vm.priceDrops.last?.uuid else { return }
                                        Task { await vm.loadMorePriceDrops(cityId: cityStore.selectedCityId) }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if vm.isLoadingMorePriceDrops {
                                PaginationLoader()
                            }
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
                    HStack(spacing: 3) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isDarkMode.toggle() }
                        } label: {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.appPrimary)
                                .frame(width: 28, height: 28)
                                .background(Color.appPrimary.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isDarkMode ? "Включить светлую тему" : "Включить тёмную тему")

                        Button { showAbout = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appPrimary.opacity(0.78))
                                .frame(width: 28, height: 28)
                                .background(Color.appPrimary.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("О приложении")
                    }
                    .padding(4)
                    .background(Color.appPrimary.opacity(0.08), in: Capsule())
                    .overlay(Capsule().stroke(Color.appPrimary.opacity(0.16), lineWidth: 0.7))
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
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(cityStore.selectedCity?.name ?? "Алматы")
                                .font(.jb(12))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.appPrimary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.appPrimary.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.appPrimary.opacity(0.16), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Выбрать город")
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
                homeLoadTask?.cancel()
                await vm.load(cityId: cityStore.selectedCityId)
            }
        }
        .task {
            await vm.load(cityId: cityStore.selectedCityId)
        }
        .onChange(of: cityStore.selectedCityId) { newId in
            scheduleHomeReload(cityId: newId)
        }
        .onDisappear {
            homeLoadTask?.cancel()
        }
    }

    private func scheduleHomeReload(cityId: Int, debounce: Bool = false) {
        homeLoadTask?.cancel()
        homeLoadTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
            }
            await vm.load(cityId: cityId)
        }
    }
}

// MARK: - Subviews

private struct SectionHeader: View {
    let title: String
    let count: Int?
    var icon: String? = nil
    var accent: Color = .appPrimary

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.12), in: Circle())
            }

            Text(title)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(Color.appForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            if let count {
                countPill(count)
            }
        }
    }

    private func countPill(_ count: Int) -> some View {
        Text(compactCount(count))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.24), lineWidth: 0.7))
            .fixedSize()
    }

    private func compactCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
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
