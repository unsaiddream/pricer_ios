import Foundation
import UserNotifications
import BackgroundTasks

final class PriceAlertManager: NSObject {
    static let shared = PriceAlertManager()
    static let bgTaskId = "kz.minprice.price-check"

    private let pricesKey  = "price_alert_prices_v1"
    private let enabledKey = "price_alerts_enabled"
    private let lastCheckKey = "price_alert_last_check"
    private let favoritesKey = "favorites_v1"
    private let cityKey = "minprice_city_id"

    // MARK: - State

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var storedPrices: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: pricesKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: pricesKey) }
    }

    private var lastCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: lastCheckKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastCheckKey) }
    }

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func permissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Price seeding (no notification on first add)

    func seedPrices(from products: [Product]) {
        var prices = storedPrices
        for p in products {
            guard prices[p.uuid] == nil, let price = p.cheapestPrice else { continue }
            prices[p.uuid] = price
        }
        storedPrices = prices
    }

    // MARK: - Foreground check (throttled to once per 30 min)

    func checkIfNeeded(favorites: [Product], cityId: Int) async {
        guard isEnabled, !favorites.isEmpty else { return }
        let minInterval: TimeInterval = 30 * 60
        if let last = lastCheckDate, Date().timeIntervalSince(last) < minInterval { return }
        lastCheckDate = Date()
        await performCheck(favorites: favorites, cityId: cityId)
    }

    // MARK: - Core check logic

    func performCheck(favorites: [Product], cityId: Int) async {
        guard isEnabled else { return }
        var updated = storedPrices

        for product in favorites {
            guard let detail = try? await APIClient.shared.fetch(
                Product.self,
                path: Endpoint.product(product.uuid),
                queryItems: [URLQueryItem(name: "city_id", value: String(cityId))]
            ), let newPrice = detail.cheapestPrice else { continue }

            if let oldPrice = updated[product.uuid], newPrice < oldPrice - 0.5 {
                let pct = max(1, Int((oldPrice - newPrice) / oldPrice * 100))
                await fireNotification(
                    uuid: detail.uuid,
                    title: "Цена упала на \(pct)%",
                    body: "\(detail.title) — \(Int(newPrice)) ₸ (было \(Int(oldPrice)) ₸)"
                )
            }

            updated[product.uuid] = newPrice
        }

        storedPrices = updated
    }

    private func fireNotification(uuid: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["productUuid": uuid]

        let request = UNNotificationRequest(
            identifier: "price_\(uuid)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Background task

    func registerBGTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskId,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            PriceAlertManager.shared.handleBGTask(refresh)
        }
    }

    func scheduleBGTask() {
        let req = BGAppRefreshTaskRequest(identifier: Self.bgTaskId)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    private func handleBGTask(_ task: BGAppRefreshTask) {
        scheduleBGTask()

        let work = Task {
            guard let data = UserDefaults.standard.data(forKey: favoritesKey),
                  let favorites = try? JSONDecoder().decode([Product].self, from: data) else {
                task.setTaskCompleted(success: true)
                return
            }
            let cityId = max(UserDefaults.standard.integer(forKey: cityKey), 1)
            await self.performCheck(favorites: favorites, cityId: cityId)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = { work.cancel() }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PriceAlertManager: UNUserNotificationCenterDelegate {
    // Показываем баннер даже когда приложение в фокусе
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    // Тап по уведомлению → открыть страницу товара
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        if let uuid = response.notification.request.content.userInfo["productUuid"] as? String {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .priceAlertOpen, object: uuid)
            }
        }
        handler()
    }
}

extension Notification.Name {
    static let priceAlertOpen = Notification.Name("priceAlertOpen")
}
