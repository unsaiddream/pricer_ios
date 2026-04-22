import Foundation

@MainActor
final class CartViewModel: ObservableObject {
    @Published var summary: CartSummaryResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    func load(cart: Cart?, cityId: Int) async {
        guard let cart else { return }
        isLoading = true
        error = nil

        do {
            let items = [URLQueryItem(name: "city_id", value: String(cityId))]
            summary = try await api.fetch(CartSummaryResponse.self, path: Endpoint.cartSummary(cart.uuid), queryItems: items)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func removeItem(cart: Cart, productUuid: String, cityId: Int) async {
        let body = RemoveItemBody(productUuid: productUuid)
        do {
            var req = api.request(path: Endpoint.cartRemoveItem(cart.uuid))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            req.httpBody = try encoder.encode(body)
            let (_, _) = try await URLSession.shared.data(for: req)
            await load(cart: cart, cityId: cityId)
        } catch {}
    }

    func transferToStore(chainSource: String, items: [CartSummaryStoreItem], cityId: Int) async -> URL? {
        let transferItems = items.map {
            CartTransferItem(
                extId: String($0.extProductId ?? 0),
                quantity: $0.quantity,
                title: $0.extProductTitle,
                url: $0.url
            )
        }
        let body = CartTransferBody(chainSource: chainSource, items: transferItems, cityId: cityId)
        do {
            let response = try await api.post(CartTransferResponse.self, path: Endpoint.cartTransfer(), body: body)
            if let urlStr = response.cartUrl, let url = URL(string: urlStr) { return url }
        } catch {}
        return nil
    }
}
