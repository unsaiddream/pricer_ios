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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            if tab == .favorites {
                                Image(systemName: selected == tab ? "star.fill" : "star")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(selected == tab ? Color.appPrimary : Color.appMuted)
                            } else {
                                Image(selected == tab ? tab.activeIcon : tab.icon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .foregroundStyle(selected == tab ? Color.appPrimary : Color.appMuted)
                            }

                            if tab == .cart && cartStore.itemsCount > 0 {
                                Text("\(min(cartStore.itemsCount, 99))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.discountRed, in: Capsule())
                                    .offset(x: 8, y: -6)
                            }
                        }

                        Text(tab.title)
                            .font(.jb(9, weight: selected == tab ? .semibold : .regular))
                            .foregroundStyle(selected == tab ? Color.appPrimary : Color.appMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
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
}
