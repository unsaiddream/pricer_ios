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
    @State private var showPermissionDenied = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var displayProducts: [Product] {
        vm.enriched.isEmpty ? favoritesStore.favorites : vm.enriched
    }

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.favorites.isEmpty {
                    VStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.08))
                                .frame(width: 90, height: 90)
                            Image(systemName: "star")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.appPrimary.opacity(0.45))
                        }
                        VStack(spacing: 6) {
                            Text("Нет избранных товаров")
                                .font(.jb(17, weight: .bold))
                                .foregroundStyle(Color.appForeground)
                            Text("Нажмите ★ на странице товара,\nчтобы добавить в избранное")
                                .font(.jb(13))
                                .foregroundStyle(Color.appMuted)
                                .multilineTextAlignment(.center)
                        }
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
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                BrandTitle(text: "Избранное")
                                if vm.isLoading {
                                    HStack(spacing: 4) {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .tint(Color.appPrimary)
                                        Text("Обновление цен...")
                                            .font(.jb(11))
                                            .foregroundStyle(Color.appMuted)
                                    }
                                }
                            }
                            Spacer()
                            Button {
                                Task { await toggleAlerts() }
                            } label: {
                                Image(systemName: alertsEnabled ? "bell.fill" : "bell")
                                    .font(.system(size: 18))
                                    .foregroundStyle(alertsEnabled ? Color.appPrimary : Color.appMuted)
                                    .frame(width: 36, height: 36)
                                    .background(Color.appCard, in: Circle())
                                    .neumorphicButton()
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
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(displayProducts) { product in
                                    NavigationLink(destination: ProductView(uuid: product.uuid)) {
                                        ProductCard(product: product) {
                                            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                        }.equatable()
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
                            .padding(16)
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
                Text("Разрешите уведомления в Настройки → MinPrice, чтобы получать оповещения о снижении цен.")
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
