import Foundation

@MainActor
final class CartViewModel: ObservableObject {
    @Published var summary: CartSummaryResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    func load(cart: Cart?, cityId: Int) async {
        guard let cart, !isLoading else { return }
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
            _ = try await URLSession.shared.data(for: req)
            await load(cart: cart, cityId: cityId)
        } catch {}
    }

    func removeItems(cart: Cart, productUuids: [String], cityId: Int) async {
        guard !productUuids.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        for uuid in productUuids {
            let body = RemoveItemBody(productUuid: uuid)
            var req = api.request(path: Endpoint.cartRemoveItem(cart.uuid))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? encoder.encode(body)
            _ = try? await URLSession.shared.data(for: req)
        }
        await load(cart: cart, cityId: cityId)
    }

    func updateQuantity(cart: Cart, productUuid: String, quantity: Int, cityId: Int) async {
        guard quantity > 0 else {
            await removeItem(cart: cart, productUuid: productUuid, cityId: cityId)
            return
        }
        let body = UpdateQuantityBody(productUuid: productUuid, quantity: quantity)
        do {
            var req = api.request(path: Endpoint.cartUpdateQuantity(cart.uuid))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            req.httpBody = try encoder.encode(body)
            _ = try await URLSession.shared.data(for: req)
            await load(cart: cart, cityId: cityId)
        } catch {}
    }

    func clearCart(cart: Cart, cityId: Int) async {
        guard let summary else { return }
        var uuids = summary.cheapestPerProduct.map { $0.product.uuid }
        uuids.append(contentsOf: summary.unavailableProducts.map { $0.product.uuid })
        let unique = Array(Set(uuids))
        guard !unique.isEmpty else { return }
        isLoading = true
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        for uuid in unique {
            let body = RemoveItemBody(productUuid: uuid)
            var req = api.request(path: Endpoint.cartRemoveItem(cart.uuid))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? encoder.encode(body)
            _ = try? await URLSession.shared.data(for: req)
        }
        isLoading = false
        await load(cart: cart, cityId: cityId)
    }

    /// Открыть корзину в нативном приложении магазина (deeplink через Wolt и др.).
    /// Для Wolt-сетей (Small/Galmart/Toimart) обязателен chainSlug — иначе бэкенд
    /// не знает, в какую конкретную сеть генерировать deeplink.
    func transferToStore(chainSource: String, chainSlug: String?, items: [CartSummaryStoreItem], cityId: Int) async -> URL? {
        let transferItems = items.map {
            CartTransferItem(
                extId: String($0.extProductId ?? 0),
                quantity: $0.quantity,
                title: $0.extProductTitle,
                url: $0.url
            )
        }
        let body = CartTransferBody(chainSource: chainSource, chainSlug: chainSlug, items: transferItems, cityId: cityId)
        CrashReporter.action("cart_transfer_start", data: [
            "chain_source": chainSource,
            "chain_slug":   chainSlug ?? "",
            "items":        items.count,
        ])
        do {
            let response = try await api.post(CartTransferResponse.self, path: Endpoint.cartTransfer(), body: body)
            if let urlStr = response.cartUrl, let url = URL(string: urlStr) {
                CrashReporter.action("cart_transfer_open", data: ["chain_slug": chainSlug ?? chainSource])
                return url
            }
        } catch {
            CrashReporter.capture(error, context: ["op": "cart_transfer", "chain": chainSlug ?? chainSource])
        }
        return nil
    }
}
