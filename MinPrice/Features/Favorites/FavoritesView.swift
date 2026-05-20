import SwiftUI

@MainActor
private final class FavoritesViewModel: ObservableObject {
    @Published var enriched: [Product] = []
    @Published var isLoading = false

    private let api = APIClient.shared

    func refresh(favorites: [Product], cityId: Int) async {
        guard !favorites.isEmpty else { enriched = []; return }
        isLoading = true
        var result: [Product] = []
        for fav in favorites {
            let q = URLQueryItem(name: "city_id", value: String(cityId))
            if let fresh = try? await api.fetch(Product.self, path: Endpoint.product(fav.uuid), queryItems: [q]) {
                result.append(fresh)
            } else {
                result.append(fav)
            }
        }
        enriched = result
        isLoading = false
    }
}

struct FavoritesView: View {
    @EnvironmentObject var favoritesStore: FavoritesStore
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var cityStore: CityStore

    @StateObject private var vm = FavoritesViewModel()
    @AppStorage("price_alerts_enabled") private var alertsEnabled = false
    @AppStorage("price_alert_threshold_pct") private var alertThreshold = 5
    @State private var showPermissionDenied = false
    @State private var showThresholdPicker = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var displayProducts: [Product] {
        vm.enriched.isEmpty ? favoritesStore.favorites : vm.enriched
    }

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.favorites.isEmpty {
                    VStack(spacing: 18) {
                        ErrorStateView(
                            .empty(
                                title: "Нет избранных товаров",
                                message: "Добавляйте товары в избранное, чтобы отслеживать цену",
                                systemImage: "star"
                            )
                        )
                        .frame(maxHeight: 260)
                        Button {
                            NotificationCenter.default.post(name: .switchTab, object: Tab.catalog)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Найти товары")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(LinearGradient.brandPrimary, in: Capsule())
                            .shadow(color: Color.appPrimary.opacity(0.30), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                } else {
                    ScrollView {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                BrandTitle(text: "Избранное",
                                           eyebrow: "Отслеживаем ваши товары",
                                           accent: Color.appPrimary)
                                HStack(spacing: 8) {
                                    AppMetricPill(
                                        icon: "star.fill",
                                        text: "\(favoritesStore.favorites.count) товаров",
                                        tint: Color.appPrimary
                                    )
                                    if vm.isLoading {
                                        HStack(spacing: 5) {
                                            ProgressView()
                                                .scaleEffect(0.62)
                                                .tint(Color.appPrimary)
                                            Text("Обновляю")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.appMuted)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.appCard, in: Capsule())
                                        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.7))
                                    }
                                }
                            }
                            Spacer()
                            if alertsEnabled {
                                Button {
                                    showThresholdPicker = true
                                } label: {
                                    Text("−\(alertThreshold)%")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundStyle(Color.appPrimary)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Color.appPrimary.opacity(0.12), in: Capsule())
                                        .overlay(Capsule().stroke(Color.appPrimary.opacity(0.25), lineWidth: 0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                Task { await toggleAlerts() }
	                            } label: {
	                                Image(systemName: alertsEnabled ? "bell.fill" : "bell")
	                                    .font(.system(size: 18))
	                                    .foregroundStyle(alertsEnabled ? Color.appPrimary : Color.appMuted)
	                                    .frame(width: 40, height: 40)
	                                    .background(Color.appCard, in: Circle())
	                                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 1))
	                            }
	                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

	                        if vm.isLoading && vm.enriched.isEmpty {
	                            SkeletonCardGrid(count: favoritesStore.favorites.count)
	                                .padding(.horizontal, 16)
	                                .padding(.top, 8)
	                        } else {
	                            AppSectionHeader(
	                                title: "Ваши товары",
	                                subtitle: "С актуальными ценами",
	                                icon: "bag.fill",
	                                accent: Color.appPrimary
	                            )
	                            .padding(.horizontal, 16)
	                            .padding(.top, 8)
	                            .padding(.bottom, 10)

	                            LazyVGrid(columns: columns, spacing: 12) {
	                                ForEach(displayProducts) { product in
                                    NavigationLink(destination: ProductView(uuid: product.uuid)) {
                                        ProductCardWrapper(product: product)
                                    }
                                    .buttonStyle(.pressScale)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation { favoritesStore.toggle(product) }
                                        } label: {
                                            Label("Удалить из избранного", systemImage: "star.slash")
                                        }
                                        Button {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        } label: {
                                            Label("В корзину", systemImage: "cart.badge.plus")
                                        }
                                    }
	                                }
	                            }
	                            .padding(.horizontal, 16)
	                            .padding(.bottom, 160)
	                        }
                    }
                    .background(Color.appBackground)
                    .refreshable {
                        await vm.refresh(favorites: favoritesStore.favorites, cityId: cityStore.selectedCityId)
                        WidgetDataStore.syncFavorites(favoritesStore.favorites)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                // Small delay so APIClient.initSession() completes first
                try? await Task.sleep(nanoseconds: 800_000_000)
                await vm.refresh(favorites: favoritesStore.favorites, cityId: cityStore.selectedCityId)
            }
            .onChange(of: cityStore.selectedCityId) { newId in
                Task { await vm.refresh(favorites: favoritesStore.favorites, cityId: newId) }
            }
            .onChange(of: favoritesStore.favorites.count) { _ in
                Task { await vm.refresh(favorites: favoritesStore.favorites, cityId: cityStore.selectedCityId) }
            }
            .alert("Уведомления отключены", isPresented: $showPermissionDenied) {
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Разрешите уведомления в Настройки → minprice, чтобы получать оповещения о снижении цен.")
            }
            .sheet(isPresented: $showThresholdPicker) {
                AlertThresholdPicker(threshold: $alertThreshold)
                    .presentationDetents([.height(360)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func toggleAlerts() async {
        if alertsEnabled {
            alertsEnabled = false
            PriceAlertManager.shared.isEnabled = false
            return
        }

        let status = await PriceAlertManager.shared.permissionStatus()
        switch status {
        case .notDetermined:
            let granted = await PriceAlertManager.shared.requestPermission()
            if granted {
                alertsEnabled = true
                PriceAlertManager.shared.isEnabled = true
                PriceAlertManager.shared.seedPrices(from: favoritesStore.favorites)
            }
        case .authorized, .provisional, .ephemeral:
            alertsEnabled = true
            PriceAlertManager.shared.isEnabled = true
            PriceAlertManager.shared.seedPrices(from: favoritesStore.favorites)
        case .denied:
            showPermissionDenied = true
        @unknown default:
            break
        }
    }
}
