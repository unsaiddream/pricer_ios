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

    func loadActiveCart(cityId: Int) async {
        do {
            let response = try await api.fetch(CartsResponse.self, path: Endpoint.carts())
            cart = response.results.first(where: { $0.isActive })
            // Don't set itemsCount here — CartView summary is the authoritative source
            syncWidget()
            updateBadge()
        } catch {
            // On error (404, network) reset to safe empty state
            cart = nil
            itemsCount = 0
            updateBadge()
        }
    }

    func quickAdd(productUuid: String, quantity: Int = 1) async throws {
        let body = AddItemBody(productUuid: productUuid, quantity: quantity)
        do {
            let response = try await api.post(QuickAddResponse.self, path: Endpoint.cartQuickAdd(), body: body)
            cart = try? await api.fetch(Cart.self, path: Endpoint.cart(response.cartUuid))
            itemsCount = response.itemsCount
            refreshCount += 1
            syncWidget()
            updateBadge()
            HapticManager.success()
            showToast("Товар добавлен")
        } catch {
            HapticManager.error()
            showToast("Не удалось добавить товар", isError: true)
            throw error
        }
    }

    private func syncWidget() {
        var total: Double = 0
        if let items = cart?.items {
            for item in items {
                let unitPrice: Double = item.product.cheapestPrice ?? 0
                total += unitPrice * Double(item.quantity)
            }
        }
        WidgetDataStore.syncCart(count: itemsCount, total: total)
    }

    private func updateBadge() {
        let count = itemsCount
        if #available(iOS 16.0, *) {
            Task {
                let center = UNUserNotificationCenter.current()
                let status = await center.notificationSettings().authorizationStatus
                if status == .notDetermined {
                    try? await center.requestAuthorization(options: [.badge])
                }
                try? await center.setBadgeCount(count)
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
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
