import Foundation

/// Готовый агрегат для главного графика — собирается на бэкенде через SQL + Python,
/// чтобы не делать 3-12 запросов с клиента и не считать Honesty Score на устройстве.
///
/// Запрос: GET /api/home/basket/?city_id=1&category_id=42&period=now
/// Параметры:
///   - city_id        — обязательно
///   - category_id    — опционально; если не задан, бэк сам выбирает по дню (rotation)
///   - period         — now | month | quarter (дефолт now)
///
/// Кэширование: бэк должен кэшировать ответ в Redis на 5 минут с ключом
/// (city_id, category_id, period). На pop-запросы (главная) это критично.
struct StoreBasketResponse: Codable {

    // Какой каталог посчитан (для отображения в шапке)
    let category: BasketCategory?

    // Период (эхо от запроса) и сколько товаров вошло в выборку
    let period: String          // "now" | "month" | "quarter"
    let coverageCount: Int      // товаров, доступных хотя бы в 2 магазинах

    // Колонки для bar-чарта (по 1 на каждую известную сеть)
    let columns: [Column]

    // Точки для line-чарта (старт периода → середина → сейчас, по магазину)
    let linePoints: [LinePoint]

    // Версия агрегатора — пригодится если методику будем менять
    let aggregatorVersion: Int?

    struct BasketCategory: Codable {
        let id: Int
        let name: String
        let emoji: String?
    }

    struct Column: Codable, Identifiable {
        var id: String { slug }
        let slug: String              // chain_slug — основной ключ
        let name: String              // отображаемое имя
        let logoUrl: String?          // chain_logo URL с бэка
        let colorHex: String?         // фирменный цвет (#RRGGBB) — может перебивать BrandPalette

        // Метрики (всё уже посчитано на бэке)
        let average: Double           // средняя цена товара в этом магазине
        let basketTotal: Double       // сумма цен по всем товарам пересечения
        let wins: Int                 // сколько раз магазин был самым дешёвым
        let winShare: Double          // доля побед, 0..100
        let honestyScore: Double      // главная метрика, 0..100 (после Bayesian smoothing)
        let overpayPercent: Double    // средняя переплата vs минимума, 0..100+
        let coveredCount: Int         // в скольки товарах магазин участвует
        let hasData: Bool
    }

    struct LinePoint: Codable, Identifiable {
        var id: String { "\(slug)_\(date.timeIntervalSince1970)" }
        let slug: String
        let date: Date
        let price: Double
    }
}

extension StoreBasketResponse {
    /// Возвращает Date из ISO8601 строки (чтобы декодер не упал на разных форматах).
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
}
