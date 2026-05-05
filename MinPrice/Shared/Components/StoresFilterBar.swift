import SwiftUI

/// Hero-блок на главной — горизонтальная лента кружков-магазинов.
/// Кликабельные, multi-select. Выбор хранится в FavoriteStoresStore (UserDefaults),
/// и автоматически прилипает ко всем product-запросам через APIClient.
struct StoresFilterBar: View {
    @ObservedObject private var store = FavoriteStoresStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сравнение цен на продукты")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appForeground)
                    Text(subtitle)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.appMuted)
                }
                Spacer(minLength: 8)
                if !store.selectedIds.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            store.clear()
                        }
                    } label: {
                        Text("Сброс")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.appPrimary.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if store.chains.isEmpty {
                // Skeleton — пока сети не приехали
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .fill(Color.appBorder.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.chains) { chain in
                            StoreCircle(
                                chain: chain,
                                isSelected: store.selectedIds.contains(chain.id),
                                onTap: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                        store.toggle(chain.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appPrimary.opacity(0.12), lineWidth: 1)
        )
    }

    private var subtitle: String {
        if store.selectedIds.isEmpty {
            return "Находим минимальную цену в \(store.chains.count) магазин\(suffix(store.chains.count))"
        }
        return "Выбрано \(store.selectedIds.count) из \(store.chains.count)"
    }

    private func suffix(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "ах" }
        if m10 == 1 { return "е" }
        if m10 >= 2 && m10 <= 4 { return "ах" }
        return "ах"
    }
}

private struct StoreCircle: View {
    let chain: Chain
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .overlay(
                        Circle().stroke(
                            isSelected ? Color.appPrimary : Color.appBorder.opacity(0.5),
                            lineWidth: isSelected ? 2 : 1
                        )
                    )
                    .shadow(
                        color: isSelected ? Color.appPrimary.opacity(0.30) : .clear,
                        radius: 6, x: 0, y: 2
                    )

                StoreLogoView(url: chain.logoURL, slug: chain.slug, source: chain.source, size: 38)
                    .clipShape(Circle())
                    .opacity(isSelected ? 1.0 : 0.85)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appPrimary)
                        .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                        .offset(x: 16, y: -16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 48, height: 48)
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
