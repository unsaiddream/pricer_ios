import Foundation

@MainActor
final class CartViewModel: ObservableObject {
    @Published var summary: CartSummaryResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    @discardableResult
    func load(cart: Cart?, cityId: Int) async -> CartSummaryResponse? {
        guard let cart, !isLoading else { return nil }
        isLoading = true
        error = nil

        var loadedSummary: CartSummaryResponse?
        do {
            let items = [URLQueryItem(name: "city_id", value: String(cityId))]
            loadedSummary = try await api.fetch(CartSummaryResponse.self, path: Endpoint.cartSummary(cart.uuid), queryItems: items)
            summary = loadedSummary
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
            }
        }

        if !Task.isCancelled { isLoading = false }
        return loadedSummary
    }

    @discardableResult
    func removeItem(cart: Cart, productUuid: String, cityId: Int) async -> CartSummaryResponse? {
        let body = RemoveItemBody(productUuid: productUuid)
        do {
            try await api.postVoid(path: Endpoint.cartRemoveItem(cart.uuid), body: body)
            return await load(cart: cart, cityId: cityId)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
                Log.debug("❌ removeItem failed: \(error)")
            }
        }
        return nil
    }

    @discardableResult
    func removeItems(cart: Cart, productUuids: [String], cityId: Int) async -> CartSummaryResponse? {
        guard !productUuids.isEmpty else { return nil }
        var failedCount = 0
        for uuid in productUuids {
            let body = RemoveItemBody(productUuid: uuid)
            do {
                try await api.postVoid(path: Endpoint.cartRemoveItem(cart.uuid), body: body)
            } catch {
                if !error.isCancellation {
                    failedCount += 1
                    Log.debug("❌ removeItems failed for \(uuid): \(error)")
                }
            }
        }
        if failedCount > 0 {
            self.error = "Не удалось удалить \(failedCount) из \(productUuids.count) товаров"
        }
        return await load(cart: cart, cityId: cityId)
    }

    @discardableResult
    func updateQuantity(cart: Cart, productUuid: String, quantity: Int, cityId: Int) async -> CartSummaryResponse? {
        guard quantity > 0 else {
            return await removeItem(cart: cart, productUuid: productUuid, cityId: cityId)
        }
        let body = UpdateQuantityBody(productUuid: productUuid, quantity: quantity)
        do {
            try await api.patchVoid(path: Endpoint.cartUpdateQuantity(cart.uuid), body: body)
            return await load(cart: cart, cityId: cityId)
        } catch {
            if !error.isCancellation {
                self.error = error.localizedDescription
                Log.debug("❌ updateQuantity failed: \(error)")
            }
        }
        return nil
    }

    @discardableResult
    func clearCart(cart: Cart, cityId: Int) async -> CartSummaryResponse? {
        guard let summary else { return nil }
        var uuids = summary.cheapestPerProduct.map { $0.product.uuid }
        uuids.append(contentsOf: summary.unavailableProducts.map { $0.product.uuid })
        let unique = Array(Set(uuids))
        guard !unique.isEmpty else { return nil }
        isLoading = true
        var failedCount = 0
        for uuid in unique {
            let body = RemoveItemBody(productUuid: uuid)
            do {
                try await api.postVoid(path: Endpoint.cartRemoveItem(cart.uuid), body: body)
            } catch {
                if !error.isCancellation {
                    failedCount += 1
                    Log.debug("❌ clearCart failed for \(uuid): \(error)")
                }
            }
        }
        if failedCount > 0 {
            self.error = "Не удалось удалить \(failedCount) товаров"
        }
        if !Task.isCancelled { isLoading = false }
        return await load(cart: cart, cityId: cityId)
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
