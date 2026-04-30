import Foundation
import Sentry

/// Обёртка над Sentry SDK.
///
/// DSN читается из Info.plist по ключу `SENTRY_DSN`. Если ключа нет или он
/// пустой — Sentry не запускается, и весь модуль работает как no-op.
/// Это удобно для локальной разработки и для билдов без crash-reporting.
///
/// Чтобы DSN не лежал в репо, в `project.yml` мы прокидываем его через
/// `INFOPLIST_KEY_SENTRY_DSN: $(SENTRY_DSN)` — а Build Setting `SENTRY_DSN`
/// заполняется из xcconfig / CI env. См. docs/RELEASE_CHECKLIST.md.
enum CrashReporter {

    static func start() {
        guard let dsn = Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String,
              !dsn.isEmpty,
              dsn != "$(SENTRY_DSN)" // пустая placeholder-подстановка
        else {
            Log.debug("Sentry: DSN не задан, crash-reporting выключен")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = Self.bundleVersionString()
            options.environment = Self.environmentName()

            // Performance monitoring отключаем — у нас нет budget'а на трейсы
            // и они шумят. Только crashes/errors.
            options.tracesSampleRate = 0.0
            options.profilesSampleRate = 0.0

            // Не отправляем PII по умолчанию (не имени, ни IP).
            options.sendDefaultPii = false

            // Игнорируем автоматический ANR-detector в DEBUG — иначе при
            // подключённом отладчике каждое breakpoint-ожидание = false-positive.
            #if DEBUG
            options.enableAppHangTracking = false
            #endif
        }
    }

    /// Записать ошибку из Swift-кода. Не показывает alert, просто логирует.
    static func capture(_ error: Error, context: [String: Any] = [:]) {
        Log.error("CrashReporter.capture:", error, context)
        SentrySDK.capture(error: error) { scope in
            for (k, v) in context { scope.setExtra(value: v, key: k) }
        }
    }

    static func captureMessage(_ message: String, level: SentryLevel = .info) {
        Log.debug("CrashReporter.message:", message)
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
        }
    }

    /// Записать breadcrumb — мини-событие в цепочку перед крэшем.
    /// Не отправляется в Sentry самостоятельно, прикрепляется автоматически
    /// к следующему `capture(...)`. Используем для ключевых действий
    /// пользователя, чтобы при разборе крэша было понятно «что он делал
    /// до этого».
    ///
    /// Категории: `ui`, `nav`, `cart`, `network`, `analytics`.
    static func breadcrumb(_ message: String, category: String = "ui", data: [String: Any] = [:]) {
        let crumb = Breadcrumb()
        crumb.category = category
        crumb.message = message
        crumb.level = .info
        if !data.isEmpty { crumb.data = data }
        SentrySDK.addBreadcrumb(crumb)
        Log.debug("[\(category)] \(message)", data)
    }

    // MARK: - Высокоуровневые helper'ы (используются по всему UI)

    /// Открытие экрана — основа навигационной телеметрии.
    static func screen(_ name: String, data: [String: Any] = [:]) {
        breadcrumb("screen \(name)", category: "nav", data: data)
    }

    /// Действие пользователя — кнопка, тап, добавление в корзину и т.п.
    static func action(_ name: String, data: [String: Any] = [:]) {
        breadcrumb(name, category: "analytics", data: data)
    }

    /// Прикрепляет user-id (guest UUID) к будущим event'ам, чтобы видеть
    /// сколько уникальных гостей затронул крэш. Без email/имени.
    static func setGuestUUID(_ uuid: String?) {
        let user = User()
        user.userId = uuid ?? "anonymous"
        SentrySDK.setUser(user)
    }

    // MARK: - Helpers

    private static func bundleVersionString() -> String {
        let bundle = Bundle.main
        let v = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let b = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "kz.minprice.app@\(v)+\(b)"
    }

    private static func environmentName() -> String {
        #if DEBUG
        return "debug"
        #else
        return "production"
        #endif
    }
}
