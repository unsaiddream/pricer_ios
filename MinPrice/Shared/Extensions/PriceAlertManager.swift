import Foundation
import UserNotifications
import BackgroundTasks

final class PriceAlertManager: NSObject {
    static let shared = PriceAlertManager()
    static let bgTaskId = "kz.minprice.price-check"

    private let pricesKey  = "price_alert_prices_v1"
    private let enabledKey = "price_alerts_enabled"
    private let nextCheckKey = "price_alert_next_check"
    private let favoritesKey = "favorites_v1"
    private let cityKey = "minprice_city_id"
    private let thresholdKey = "price_alert_threshold_pct"

    // MARK: - State

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                ensureNextCheckDate()
                scheduleBGTask()
            } else {
                nextCheckDate = nil
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskId)
            }
        }
    }

    /// Минимальный процент снижения для отправки уведомления.
    /// Default 5% — иначе шумит на каждом копеечном тике.
    /// Настраивается пользователем (см. AlertThresholdPicker в Favorites).
    var thresholdPercent: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: thresholdKey)
            return v > 0 ? v : 5
        }
        set { UserDefaults.standard.set(newValue, forKey: thresholdKey) }
    }

    static let availableThresholds: [Int] = [3, 5, 10, 15, 20, 30]

    private var storedPrices: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: pricesKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: pricesKey) }
    }

    private var nextCheckDate: Date? {
        get { UserDefaults.standard.object(forKey: nextCheckKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: nextCheckKey) }
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

    // MARK: - Foreground check (daily due gate)

    func checkIfNeeded(favorites: [Product], cityId: Int) async {
        guard isEnabled, !favorites.isEmpty else { return }
        let now = Date()
        guard Self.isDailyCheckDue(now: now, nextCheckDate: nextCheckDate) else { return }
        nextCheckDate = Self.nextDailyCheckDate(afterCompletedCheckAt: now)
        await performCheck(favorites: favorites, cityId: cityId)
        scheduleBGTask()
    }

    // MARK: - Core check logic

    func performCheck(favorites: [Product], cityId: Int) async {
        guard isEnabled else { return }
        var updated = storedPrices
        let threshold = Double(thresholdPercent)

        for product in favorites {
            if Task.isCancelled { break }
            guard let detail = try? await APIClient.shared.fetch(
                Product.self,
                path: Endpoint.product(product.uuid),
                queryItems: [URLQueryItem(name: "city_id", value: String(cityId))]
            ), let newPrice = detail.cheapestPrice else { continue }

            if let oldPrice = updated[product.uuid], newPrice < oldPrice {
                let pct = (oldPrice - newPrice) / oldPrice * 100
                // Только если падение >= порога. Иначе тихо обновляем baseline,
                // не шумим уведомлениями на копеечные движения.
                if pct >= threshold {
                    let pctInt = max(1, Int(pct))
                    await fireNotification(
                        uuid: detail.uuid,
                        title: "Цена упала на \(pctInt)%",
                        body: "\(detail.title) — \(formatPriceTg(newPrice)) (было \(formatPriceTg(oldPrice)))"
                    )
                }
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

    static func isDailyCheckDue(now: Date, nextCheckDate: Date?) -> Bool {
        guard let nextCheckDate else { return true }
        return now >= nextCheckDate
    }

    static func nextDailyCheckDate(
        afterCompletedCheckAt date: Date,
        calendar: Calendar = .current,
        random: () -> Double = { Double.random(in: 0..<1) }
    ) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(24 * 60 * 60)
        return randomCheckDate(onDayContaining: nextDay, calendar: calendar, random: random)
    }

    static func nextInitialCheckDate(
        after date: Date,
        calendar: Calendar = .current,
        random: () -> Double = { Double.random(in: 0..<1) }
    ) -> Date {
        let today = randomCheckDate(onDayContaining: date, calendar: calendar, random: random)
        if today > date.addingTimeInterval(5 * 60) {
            return today
        }
        return nextDailyCheckDate(afterCompletedCheckAt: date, calendar: calendar, random: random)
    }

    private static func randomCheckDate(
        onDayContaining date: Date,
        calendar: Calendar,
        random: () -> Double
    ) -> Date {
        let start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let end = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: date) ?? start.addingTimeInterval(12 * 60 * 60)
        let span = max(end.timeIntervalSince(start), 60)
        let fraction = min(max(random(), 0), 0.999_999)
        return start.addingTimeInterval(span * fraction)
    }

    private func ensureNextCheckDate() {
        guard nextCheckDate == nil else { return }
        nextCheckDate = Self.nextInitialCheckDate(after: Date())
    }

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
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskId)
            return
        }
        ensureNextCheckDate()
        let req = BGAppRefreshTaskRequest(identifier: Self.bgTaskId)
        req.earliestBeginDate = nextCheckDate ?? Self.nextInitialCheckDate(after: Date())
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskId)
        try? BGTaskScheduler.shared.submit(req)
    }

    private func handleBGTask(_ task: BGAppRefreshTask) {
        let work = Task {
            defer { self.scheduleBGTask() }
            guard self.isEnabled else {
                task.setTaskCompleted(success: true)
                return
            }
            let now = Date()
            guard Self.isDailyCheckDue(now: now, nextCheckDate: self.nextCheckDate) else {
                task.setTaskCompleted(success: true)
                return
            }
            self.nextCheckDate = Self.nextDailyCheckDate(afterCompletedCheckAt: now)

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
    /// Запрос переключиться на вкладку (object: Tab). Используется для CTA из
    /// empty-states — например, "Перейти в каталог" с пустого избранного.
    static let switchTab = Notification.Name("switchTab")
}
