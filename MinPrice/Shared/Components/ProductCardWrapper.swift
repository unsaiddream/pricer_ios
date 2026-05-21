import SwiftUI

// Обёртка над ProductCard, которая сама читает CartStore.
// Каждая карточка — независимый View, который re-рендерится только когда
// меняется именно её количество в корзине (по refreshCount).
// Это предотвращает ситуацию когда добавление одного товара перересовывает
// всю сетку ProductCard.
struct ProductCardWrapper: View {
    let product: Product
    @EnvironmentObject private var cartStore: CartStore

    @State private var localCartCount: Int = 0

    var body: some View {
        ProductCard(
            product: product,
            cartCount: localCartCount
        ) {
            Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
        } onRemove: {
            Task { await cartStore.quickDecrement(productUuid: product.uuid) }
        }
        .equatable()
        .onAppear { syncCount() }
        .onChange(of: cartStore.refreshCount) { _ in syncCount() }
    }

    private func syncCount() {
        let qty = cartStore.cart?.items.first(where: { $0.product.uuid == product.uuid })?.quantity ?? 0
        if localCartCount != qty { localCartCount = qty }
    }
}
