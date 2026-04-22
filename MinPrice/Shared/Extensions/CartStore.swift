import SwiftUI

@MainActor
final class CartStore: ObservableObject {
    @Published var cart: Cart?
    @Published var itemsCount: Int = 0
    @Published var toastMessage: String? = nil
    @Published var toastIsError: Bool = false

    private let api = APIClient.shared

    func loadActiveCart(cityId: Int) async {
        do {
            let response = try await api.fetch(CartsResponse.self, path: Endpoint.carts())
            cart = response.results.first(where: { $0.isActive })
            itemsCount = cart?.itemsCount ?? 0
        } catch {}
    }

    func quickAdd(productUuid: String, quantity: Int = 1) async throws {
        let body = AddItemBody(productUuid: productUuid, quantity: quantity)
        do {
            let response = try await api.post(QuickAddResponse.self, path: Endpoint.cartQuickAdd(), body: body)
            cart = try? await api.fetch(Cart.self, path: Endpoint.cart(response.cartUuid))
            itemsCount = response.itemsCount
            showToast("Товар добавлен")
        } catch {
            print("❌ addItem failed: \(error)")
            showToast("Не удалось добавить товар", isError: true)
            throw error
        }
    }

    func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        toastIsError = isError
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            toastMessage = nil
        }
    }

}
