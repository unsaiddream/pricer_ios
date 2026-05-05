import SwiftUI

enum Tab: Int, CaseIterable {
    case home, catalog, discounts, favorites, cart

    var title: String {
        switch self {
        case .home:      return "Главная"
        case .catalog:   return "Каталог"
        case .discounts: return "Скидки"
        case .favorites: return "Избранное"
        case .cart:      return "Корзина"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "tab_home"
        case .catalog:   return "tab_catalog"
        case .discounts: return "tab_discounts"
        case .favorites: return "tab_favorites"
        case .cart:      return "tab_cart"
        }
    }

    var activeIcon: String { icon + "_active" }
}

struct CustomTabBar: View {
    @Binding var selected: Tab
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @Namespace private var pillNS

    /// Список табов с учётом feature-флагов из RemoteConfig.
    /// Сейчас только discounts можно отключать; остальные — основа навигации.
    private var visibleTabs: [Tab] {
        Tab.allCases.filter { tab in
            if tab == .discounts && !ConfigSnapshot.isEnabled(.discountsTab) {
                return false
            }
            return true
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                tabButton(tab: tab)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .fill(Color.white.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func tabButton(tab: Tab) -> some View {
        let isActive = selected == tab
        Button {
            if !isActive {
                HapticManager.selection()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    selected = tab
                }
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.16))
                            .overlay(Capsule().stroke(Color.appPrimary.opacity(0.25), lineWidth: 0.5))
                            .frame(width: 50, height: 32)
                            .matchedGeometryEffect(id: "tab_pill", in: pillNS)
                    }
                    iconWithBadge(tab: tab, isActive: isActive)
                        .scaleEffect(isActive ? 1.05 : 1.0)
                }
                .frame(height: 32)

                Text(tab.title)
                    .font(.jb(9, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? Color.appPrimary : Color.appMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconWithBadge(tab: Tab, isActive: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            tabIcon(for: tab, active: isActive)
            if tab == .cart, cartStore.itemsCount > 0 {
                BadgeView(count: cartStore.itemsCount, color: Color.discountRed)
                    .offset(x: 10, y: -7)
            }
            if tab == .favorites, favoritesStore.favorites.count > 0 {
                BadgeView(count: favoritesStore.favorites.count, color: Color.appPrimary)
                    .offset(x: 10, y: -7)
            }
        }
    }

    @ViewBuilder
    private func tabIcon(for tab: Tab, active: Bool) -> some View {
        let color: Color = active ? Color.appPrimary : Color.appMuted
        switch tab {
        case .favorites:
            Image(systemName: active ? "star.fill" : "star")
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(color)
        case .discounts:
            Image(systemName: active ? "flame.fill" : "flame")
                .resizable().scaledToFit()
                .frame(width: 21, height: 21)
                .foregroundStyle(color)
        default:
            Image(active ? tab.activeIcon : tab.icon)
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Badge

private struct BadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(min(count, 99))")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                ZStack {
                    Capsule().fill(color)
                    // Глянцевая подсветка сверху для премиум-вида
                    Capsule().fill(LinearGradient(
                        colors: [.white.opacity(0.30), .clear],
                        startPoint: .top, endPoint: .center
                    ))
                }
            }
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5))
            .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 1)
    }
}
