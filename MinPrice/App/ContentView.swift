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
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var favoritesStore: FavoritesStore

    private let tabOrder = Tab.allCases

    var body: some View {
        ZStack(alignment: .bottom) {
            // Основные экраны
            ZStack {
                HomeView()
                    .opacity(selectedTab == .home ? 1 : 0)
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
                CatalogView()
                    .opacity(selectedTab == .catalog ? 1 : 0)
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
                DiscountsView()
                    .opacity(selectedTab == .discounts ? 1 : 0)
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
                FavoritesView()
                    .opacity(selectedTab == .favorites ? 1 : 0)
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
                CartView()
                    .opacity(selectedTab == .cart ? 1 : 0)
                    .animation(.easeInOut(duration: 0.22), value: selectedTab)
            }
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
            .sheet(isPresented: $showSearch) {
                SearchView(initialQuery: scanResultQuery)
                    .onDisappear { scanResultQuery = nil }
            }
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerView(
                    onScan: { barcode in
                        showScanner = false
                        scanResultQuery = barcode
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showSearch = true
                        }
                    },
                    onDismiss: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .onPreferenceChange(HideBottomBarsKey.self) { value in
                withAnimation(.easeInOut(duration: 0.22)) {
                    hideBottomBars = value
                }
            }

            if !hideBottomBars {
                // Bottom search bar
                BottomSearchBar {
                    showSearch = true
                } onScan: {
                    showScanner = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 104)
                .zIndex(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))

                // Tab bar
                CustomTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Toast
            if let message = cartStore.toastMessage {
                CartToast(message: message, isError: cartStore.toastIsError)
                    .padding(.bottom, hideBottomBars ? 40 : 170)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartStore.toastMessage)
                    .zIndex(100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cartStore.toastMessage)
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

private struct CartToast: View {
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
