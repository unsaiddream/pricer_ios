import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesStore: FavoritesStore
    @EnvironmentObject var cartStore: CartStore

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.favorites.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.appMuted.opacity(0.35))
                        Text("Нет избранных товаров")
                            .font(.jb(16, weight: .semibold))
                            .foregroundStyle(Color.appForeground)
                        Text("Нажмите ★ на странице товара\nчтобы добавить в избранное")
                            .font(.jb(13))
                            .foregroundStyle(Color.appMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(favoritesStore.favorites) { product in
                                NavigationLink(destination: ProductView(uuid: product.uuid)) {
                                    ProductCard(product: product) {
                                        Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 160)
                    }
                    .background(Color.appBackground)
                }
            }
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Избранное")
                        .font(.jb(16, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
