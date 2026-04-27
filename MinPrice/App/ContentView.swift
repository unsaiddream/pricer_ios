import SwiftUI

// Preference key — ProductView сигналит скрыть нижние бары
struct HideBottomBarsKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showSearch = false
    @State private var showScanner = false
    @State private var scanResultQuery: String? = nil
    @State private var hideBottomBars = false
    @State private var alertProductUuid: String? = nil
    @State private var barcodeProductUuid: String? = nil
    @State private var isBarcodeLoading = false
    @State private var barcodeNotFound = false
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @EnvironmentObject var cityStore: CityStore

    private let tabOrder = Tab.allCases

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                // Каждый экран hit-тестится только когда выбран — иначе таб
                // под ним перехватывает скроллы соседнего и тратит CPU.
                HomeView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .allowsHitTesting(selectedTab == .home)
                CatalogView()
                    .opacity(selectedTab == .catalog ? 1 : 0)
                    .allowsHitTesting(selectedTab == .catalog)
                DiscountsView()
                    .opacity(selectedTab == .discounts ? 1 : 0)
                    .allowsHitTesting(selectedTab == .discounts)
                FavoritesView()
                    .opacity(selectedTab == .favorites ? 1 : 0)
                    .allowsHitTesting(selectedTab == .favorites)
                CartView()
                    .opacity(selectedTab == .cart ? 1 : 0)
                    .allowsHitTesting(selectedTab == .cart)
            }
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard !hideBottomBars else { return }
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy) * 1.4 else { return }
                        guard let idx = tabOrder.firstIndex(of: selectedTab) else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if dx < 0, idx < tabOrder.count - 1 {
                                selectedTab = tabOrder[idx + 1]
                            } else if dx > 0, idx > 0 {
                                selectedTab = tabOrder[idx - 1]
                            }
                        }
                    }
            )
            .fullScreenCover(isPresented: $showSearch) {
                SearchView(initialQuery: scanResultQuery, onDismiss: { showSearch = false })
                    .onDisappear { scanResultQuery = nil }
            }
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView(
                    onScan: { barcode in
                        showScanner = false
                        Task { await handleBarcodeScan(barcode) }
                    },
                    onDismiss: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(item: Binding(
                get: { barcodeProductUuid.map { BarcodeResult(uuid: $0) } },
                set: { barcodeProductUuid = $0?.uuid }
            )) { result in
                NavigationStack { ProductView(uuid: result.uuid) }
            }
            .onPreferenceChange(HideBottomBarsKey.self) { value in
                withAnimation(.easeInOut(duration: 0.22)) { hideBottomBars = value }
            }

            if !hideBottomBars {
                BottomSearchBar {
                    showSearch = true
                } onScan: {
                    showScanner = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 104)
                .zIndex(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))

                CustomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Лоадер штрихкода
            if isBarcodeLoading {
                BarcodeLoadingToast()
                    .padding(.bottom, hideBottomBars ? 40 : 170)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isBarcodeLoading)
                    .zIndex(101)
            }

            if barcodeNotFound {
                CartToast(message: "Товар не найден", isError: true)
                    .padding(.bottom, hideBottomBars ? 40 : 170)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: barcodeNotFound)
                    .zIndex(101)
            }

            // Обычный toast корзины
            if let message = cartStore.toastMessage {
                CartToast(message: message, isError: cartStore.toastIsError)
                    .padding(.bottom, hideBottomBars ? 40 : 170)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartStore.toastMessage)
                    .zIndex(100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: Binding(
            get: { alertProductUuid != nil },
            set: { if !$0 { alertProductUuid = nil } }
        )) {
            if let uuid = alertProductUuid {
                NavigationStack { ProductView(uuid: uuid) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .priceAlertOpen)) { note in
            if let uuid = note.object as? String {
                alertProductUuid = uuid
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchTab)) { note in
            if let tab = note.object as? Tab {
                withAnimation(.easeInOut(duration: 0.22)) { selectedTab = tab }
            }
        }
    }

    private func handleBarcodeScan(_ barcode: String) async {
        withAnimation { isBarcodeLoading = true }

        let cityId = cityStore.selectedCityId

        // Task.detached запускает оба запроса вне MainActor — реально параллельно
        let directTask = Task.detached { () -> String? in
            let items = [
                URLQueryItem(name: "barcode", value: barcode),
                URLQueryItem(name: "city_id", value: String(cityId)),
            ]
            return try? await APIClient.shared.fetch(
                ProductsResponse.self,
                path: Endpoint.products(),
                queryItems: items,
                timeout: 4.0
            ).results.first?.uuid
        }

        let searchTask = Task.detached { () -> String? in
            let items = [
                URLQueryItem(name: "q", value: barcode),
                URLQueryItem(name: "city_id", value: String(cityId)),
                URLQueryItem(name: "page", value: "0"),
                URLQueryItem(name: "hitsPerPage", value: "1"),
            ]
            return try? await APIClient.shared.fetch(
                SearchResponse.self,
                path: Endpoint.search(),
                queryItems: items,
                timeout: 10.0
            ).hits.first?.uuid
        }

        // Ждём быстрый lookup (max 4s), потом search (уже работал параллельно)
        let uuid: String?
        if let direct = await directTask.value {
            searchTask.cancel()
            uuid = direct
        } else {
            uuid = await searchTask.value
        }

        withAnimation { isBarcodeLoading = false }

        if let uuid {
            barcodeProductUuid = uuid
        } else {
            withAnimation { barcodeNotFound = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { barcodeNotFound = false }
        }
    }
}

private struct BarcodeResult: Identifiable {
    let uuid: String
    var id: String { uuid }
}

// MARK: - Barcode loading toast

private struct BarcodeLoadingToast: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.85)
                .tint(Color.appPrimary)
            Text("Ищем товар...")
                .font(.jb(14, weight: .semibold))
                .foregroundStyle(Color.appForeground)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Bottom Search Bar

struct BottomSearchBar: View {
    let onTap: () -> Void
    var onScan: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                    Text("Поиск товаров...")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                }
            }
            .buttonStyle(.plain)

            Button {
                onScan?()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.appPrimary)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    }
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Cart Toast

struct CartToast: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(isError ? Color.discountRed : .green)
            Text(message)
                .font(.jb(14, weight: .semibold))
                .foregroundStyle(Color.appForeground)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}
