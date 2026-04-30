import Foundation

/// Debug-only логгер.
///
/// В release-сборке (`#if DEBUG` ложно) тело функций пустое — компилятор
/// инлайнит no-op и не оставляет даже вызовов. Это значит:
/// - В консоли продакшна нет шумных HTTP/JSON логов
/// - Не утекают backend-пути и payload'ы
/// - Чуть быстрее (минус N системных вызовов)
///
/// Использование:
///   Log.debug("чё-то случилось", "детали")
///   Log.error("failed:", error)
enum Log {
    @inline(__always)
    static func debug(_ items: Any..., separator: String = " ") {
        #if DEBUG
        let line = items.map { "\($0)" }.joined(separator: separator)
        print(line)
        #endif
    }

    @inline(__always)
    static func error(_ items: Any..., separator: String = " ") {
        #if DEBUG
        let line = items.map { "\($0)" }.joined(separator: separator)
        print(line)
        #endif
    }
}
