import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class CartStore: ObservableObject {
    @Published var cart: Cart?
    @Published var itemsCount: Int = 0
    @Published var refreshCount: Int = 0
    @Published var toastMessage: String? = nil
    @Published var toastIsError: Bool = false

    private let api = APIClient.shared
    private var toastTask: Task<Void, Never>?

    func loadActiveCart(cityId: Int) async {
        do {
            let response = try await api.fetch(CartsResponse.self, path: Endpoint.carts())
            cart = response.results.first(where: { $0.isActive })
            itemsCount = cart?.itemsCount ?? 0
            refreshCount += 1
            syncWidget()
            updateBadge()
        } catch {
            // On error (404, network) reset to safe empty state
            cart = nil
            itemsCount = 0
            refreshCount += 1
            syncWidget()
            updateBadge()
        }
    }

    func quickAdd(productUuid: String, quantity: Int = 1) async throws {
        let body = AddItemBody(productUuid: productUuid, quantity: quantity)
        do {
            let response = try await api.post(QuickAddResponse.self, path: Endpoint.cartQuickAdd(), body: body)
            do {
                cart = try await api.fetch(Cart.self, path: Endpoint.cart(response.cartUuid))
            } catch {
                Log.debug("⚠️ quickAdd: failed to refresh cart after add: \(error)")
            }
            itemsCount = cart?.itemsCount ?? response.itemsCount
            refreshCount += 1
            syncWidget()
            updateBadge()
            HapticManager.success()
            showToast("Товар добавлен")
            CrashReporter.action("cart_add", data: ["product_uuid": productUuid, "qty": quantity])
        } catch {
            HapticManager.error()
            showToast("Не удалось добавить товар", isError: true)
            CrashReporter.capture(error, context: ["op": "cart_add", "product_uuid": productUuid])
            throw error
        }
    }

    func apply(summary: CartSummaryResponse, quantityOverrides: [String: Int] = [:]) {
        let snapshot = summary.cartStateSnapshot(quantityOverrides: quantityOverrides)
        cart = snapshot.cart
        itemsCount = snapshot.itemsCount
        refreshCount += 1
        syncWidget(totalOverride: snapshot.total)
        updateBadge()
    }

    func applyLocalQuantity(productUuid: String, quantity: Int, totalOverride: Double? = nil) {
        guard let cart else { return }
        let updatedItems = cart.items.compactMap { item -> CartItem? in
            guard item.product.uuid == productUuid else { return item }
            guard quantity > 0 else { return nil }
            return item.replacingQuantity(quantity)
        }
        self.cart = cart.replacingItems(updatedItems)
        itemsCount = updatedItems.reduce(0) { $0 + $1.quantity }
        syncWidget(totalOverride: totalOverride)
        updateBadge()
    }

    func syncWidget(totalOverride: Double? = nil) {
        let total: Double
        if let totalOverride {
            total = totalOverride
        } else {
            total = cart?.items.reduce(0) { partialResult, item in
                let unitPrice: Double = item.product.cheapestPrice ?? 0
                return partialResult + unitPrice * Double(item.quantity)
            } ?? 0
        }
        WidgetDataStore.syncCart(count: itemsCount, total: total)
    }

    private func updateBadge() {
        let count = itemsCount
        if #available(iOS 16.0, *) {
            Task {
                let center = UNUserNotificationCenter.current()
                let status = await center.notificationSettings().authorizationStatus
                guard Self.canUpdateBadge(for: status) else {
                    return
                }
                _ = try? await center.setBadgeCount(count)
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    nonisolated static func canUpdateBadge(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func quickDecrement(productUuid: String) async {
        guard let cartUuid = cart?.uuid else { return }
        let currentQty = cart?.items.first(where: { $0.product.uuid == productUuid })?.quantity ?? 0
        guard currentQty > 0 else { return }
        do {
            if currentQty <= 1 {
                let body = RemoveItemBody(productUuid: productUuid)
                try await api.postVoid(path: Endpoint.cartRemoveItem(cartUuid), body: body)
            } else {
                let body = UpdateQuantityBody(productUuid: productUuid, quantity: currentQty - 1)
                try await api.patchVoid(path: Endpoint.cartUpdateQuantity(cartUuid), body: body)
            }
            do {
                cart = try await api.fetch(Cart.self, path: Endpoint.cart(cartUuid))
            } catch {
                Log.debug("⚠️ quickDecrement: failed to refresh cart after update: \(error)")
            }
            itemsCount = cart?.itemsCount ?? max(0, itemsCount - 1)
            refreshCount += 1
            syncWidget()
            updateBadge()
            HapticManager.success()
        } catch {
            HapticManager.error()
            showToast("Не удалось изменить", isError: true)
            CrashReporter.capture(error, context: ["op": "cart_quick_decrement", "product_uuid": productUuid])
        }
    }

    func showToast(_ message: String, isError: Bool = false) {
        toastTask?.cancel()
        toastMessage = message
        toastIsError = isError
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }
}
