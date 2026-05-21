import SwiftUI

struct StoresFilterBar: View {
    @ObservedObject private var store = FavoriteStoresStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if store.chains.isEmpty {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonStoreTile()
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.chains) { chain in
                            StoreTile(
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
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.appCard.opacity(0.98), Color.appPrimary.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder.opacity(0.85), lineWidth: 0.8)
        )
        .shadow(color: Color.appPrimary.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28, height: 28)
                .background(Color.appPrimary.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text("Сравнить магазины")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }

            Spacer(minLength: 8)

            if !store.selectedIds.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        store.clear()
                    }
                } label: {
                    Text("Сбросить")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.appPrimary.opacity(0.10), in: Capsule())
                        .overlay(Capsule().stroke(Color.appPrimary.opacity(0.22), lineWidth: 0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var subtitle: String {
        if store.selectedIds.isEmpty {
            return "Все сети участвуют в выдаче"
        }
        return "Выбрано \(store.selectedIds.count) из \(store.chains.count) магазинов"
    }
}

private struct StoreTile: View {
    let chain: Chain
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.appPrimary.opacity(0.12) : Color.appBackground.opacity(0.72))
                    StoreLogoView(url: chain.logoURL, slug: chain.slug, source: chain.source, size: 34)
                        .opacity(isSelected ? 1.0 : 0.9)
                }
                .frame(width: 52, height: 46)
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.appPrimary, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.2))
                            .offset(x: 4, y: -4)
                    }
                }

                Text(chain.name)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Color.appPrimary : Color.appMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 64)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 7)
            .background(Color.appCard.opacity(isSelected ? 1 : 0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.appPrimary.opacity(0.55) : Color.appBorder.opacity(0.58), lineWidth: isSelected ? 1.2 : 0.8)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct SkeletonStoreTile: View {
    var body: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.appBorder.opacity(0.42))
                .frame(width: 52, height: 46)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.appBorder.opacity(0.42))
                .frame(width: 44, height: 8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(Color.appCard.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
