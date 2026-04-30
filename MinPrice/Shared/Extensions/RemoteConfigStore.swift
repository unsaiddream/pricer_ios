import Foundation
import SwiftUI

/// Хранилище серверной конфигурации.
/// Стратегия загрузки:
/// 1) При старте сразу читаем кэш из UserDefaults (last-known-good) — дает мгновенный UI.
/// 2) Параллельно делаем сетевой запрос. Если успешно — обновляем кэш и публикуем.
/// 3) Если оффлайн — продолжаем работать с кэшем; если кэша нет — используем `.fallback`.
///
/// TTL кэша мы не используем как "expire" — просто всегда стартуем с кэша
/// и сразу же пробуем обновить с сервера. Это даёт быстрый старт без блокировки.
@MainActor
final class RemoteConfigStore: ObservableObject {
    static let shared = RemoteConfigStore()

    @Published private(set) var config: AppConfig = .fallback
    @Published private(set) var isLoaded: Bool = false
    @Published private(set) var lastFetchAt: Date?

    private let cacheKey = "app_config_cache_v1"
    private let api = APIClient.shared

    private init() {
        loadFromCache()
        ConfigSnapshot.update(from: config)
    }

    // MARK: - Public API

    /// Текущая версия приложения (из CFBundleShortVersionString).
    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// Текущая build-версия (CURRENT_PROJECT_VERSION).
    static var currentBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// Загрузить конфиг с бэкенда. Безопасно: при неудаче оставляем текущий.
    func refresh() async {
        let items = [
            URLQueryItem(name: "platform", value: "ios"),
            URLQueryItem(name: "version", value: Self.currentAppVersion),
        ]
        // Короткий таймаут — конфиг не должен блокировать запуск
        if let fresh = try? await api.fetch(AppConfig.self, path: "/app-config/", queryItems: items, timeout: 4.0) {
            config = fresh
            isLoaded = true
            lastFetchAt = Date()
            saveToCache(fresh)
            ConfigSnapshot.update(from: fresh)
        } else {
            // Сеть недоступна — продолжаем с кэшем/fallback. Только помечаем что попытка была.
            isLoaded = true
        }
    }

    /// Гейт версии. Используется LaunchGate для решения какой экран показать.
    var versionGate: AppConfig.VersionGate {
        config.versionGate(currentVersion: Self.currentAppVersion)
    }

    /// Удобный shortcut для feature-flag проверок.
    func isEnabled(_ flag: AppConfig.FeatureFlag, default defaultValue: Bool = true) -> Bool {
        config.isEnabled(flag, default: defaultValue)
    }

    // MARK: - Cache

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder.snake.decode(AppConfig.self, from: data) else {
            return
        }
        config = cached
    }

    private func saveToCache(_ cfg: AppConfig) {
        guard let data = try? JSONEncoder.snake.encode(cfg) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

// MARK: - JSON helpers

private extension JSONEncoder {
    static let snake: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}

private extension JSONDecoder {
    static let snake: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}

// MARK: - Synchronous snapshot
// BrandPalette / другие nonisolated утилиты не могут трогать @MainActor store.
// Держим легковесный snapshot ключевых полей с защитой через NSLock.

enum ConfigSnapshot {
    private static let lock = NSLock()
    private static var _chainColors: [String: String] = [:]
    private static var _features: [String: Bool] = [:]

    static func update(from config: AppConfig) {
        lock.lock()
        _chainColors = config.chainColors ?? [:]
        _features = config.features ?? [:]
        lock.unlock()
    }

    static func chainColorHex(slug: String?) -> String? {
        guard let s = slug?.lowercased() else { return nil }
        lock.lock(); defer { lock.unlock() }
        return _chainColors[s]
    }

    static func isEnabled(_ flag: AppConfig.FeatureFlag, default defaultValue: Bool = true) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _features[flag.rawValue] ?? defaultValue
    }
}
