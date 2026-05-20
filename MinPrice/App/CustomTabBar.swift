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
                        .fill(Color.appCard.opacity(0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(Color.appBorder.opacity(0.88), lineWidth: 0.8)
                }
        }
        .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)
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
                            .fill(
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.20), Color.appPrimary.opacity(0.09)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(Capsule().stroke(Color.appPrimary.opacity(0.30), lineWidth: 0.8))
                            .frame(width: 54, height: 32)
                            .matchedGeometryEffect(id: "tab_pill", in: pillNS)
                    }
                    iconWithBadge(tab: tab, isActive: isActive)
                        .scaleEffect(isActive ? 1.07 : 1.0)
                }
                .frame(height: 32)

                Text(tab.title)
                    .font(.system(size: 9.5, weight: isActive ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isActive ? Color.appPrimary : Color.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
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
        switch tab {
        case .home:
            Image("AppLogo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .saturation(active ? 1.0 : 0.45)
                .opacity(active ? 1.0 : 0.62)
        case .favorites:
            Image(systemName: "star.fill")
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(iconStyle(active: active))
                .opacity(active ? 1.0 : 0.58)
                .shadow(color: active ? Color.appPrimary.opacity(0.22) : .clear, radius: 4, x: 0, y: 1)
        case .discounts:
            Image(systemName: "flame.fill")
                .resizable().scaledToFit()
                .frame(width: 21, height: 21)
                .foregroundStyle(iconStyle(active: active))
                .opacity(active ? 1.0 : 0.58)
                .shadow(color: active ? Color.appPrimary.opacity(0.22) : .clear, radius: 4, x: 0, y: 1)
        default:
            Image(tab.activeIcon)
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(iconStyle(active: active))
                .opacity(active ? 1.0 : 0.58)
                .shadow(color: active ? Color.appPrimary.opacity(0.22) : .clear, radius: 4, x: 0, y: 1)
        }
    }

    private func iconStyle(active: Bool) -> AnyShapeStyle {
        if active {
            return AnyShapeStyle(LinearGradient.brandPrimary)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color.appPrimaryLight.opacity(0.72),
                    Color.appPrimary.opacity(0.58),
                    Color.appPrimaryDeep.opacity(0.64),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Badge

private struct BadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(min(count, 99))")
            .font(.system(size: 9.5, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 5.5)
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
