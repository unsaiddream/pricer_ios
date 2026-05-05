import SwiftUI

/// "Кошелёк экономии" — суммарная экономия пользователя за всё время
/// использования minprice. Накапливается при transfer корзины в магазин:
/// savings = worstSingleStoreTotal - chosenStoreTotal.
///
/// Локальное хранение (UserDefaults), без бэкенда — счётчик личный, не sync.
/// Это намеренно: фича про эмоциональную привязку, не про точную бухгалтерию.
@MainActor
final class SavingsWalletStore: ObservableObject {
    static let shared = SavingsWalletStore()

    @AppStorage("savings_total_v1") private var storedTotal: Double = 0
    @AppStorage("savings_transfers_v1") private var storedTransfers: Int = 0
    @AppStorage("savings_first_use_v1") private var firstUseTimestamp: Double = 0
    @AppStorage("savings_unlocked_milestones_v1") private var storedMilestonesCSV: String = ""

    @Published private(set) var totalSaved: Double = 0
    @Published private(set) var transfersCount: Int = 0
    /// Только что разблокированный milestone — UI показывает тост + конфетти.
    @Published var newlyUnlocked: Milestone? = nil

    enum Milestone: Int, CaseIterable, Identifiable {
        case first = 1000
        case k5 = 5000
        case k10 = 10000
        case k25 = 25000
        case k50 = 50000
        case k100 = 100000

        var id: Int { rawValue }

        var emoji: String {
            switch self {
            case .first: return "🌱"
            case .k5:    return "💰"
            case .k10:   return "🎯"
            case .k25:   return "🏆"
            case .k50:   return "💎"
            case .k100:  return "👑"
            }
        }

        var title: String {
            switch self {
            case .first: return "Первая тысяча!"
            case .k5:    return "5К клуб"
            case .k10:   return "Десятка"
            case .k25:   return "Опытный охотник"
            case .k50:   return "Цена-эксперт"
            case .k100:  return "Легенда minprice"
            }
        }

        var subtitle: String {
            switch self {
            case .first: return "Вы сэкономили первую 1 000 ₸"
            case .k5:    return "5 000 ₸ экономии — серьёзный результат"
            case .k10:   return "10 000 ₸ — почти на месяц молочки"
            case .k25:   return "25 000 ₸ — уже большая корзина"
            case .k50:   return "50 000 ₸ — невероятно!"
            case .k100:  return "100 000 ₸ — вы в зале славы"
            }
        }
    }

    private init() {
        totalSaved = storedTotal
        transfersCount = storedTransfers
        if firstUseTimestamp == 0 {
            firstUseTimestamp = Date().timeIntervalSince1970
        }
    }

    // MARK: - Recording

    /// Зафиксировать экономию от одного transfer'а в магазин.
    /// `amount` — разница между самым дорогим single-store и выбранным.
    func recordSavings(_ amount: Double) {
        guard amount > 0 else { return }
        let oldTotal = totalSaved
        totalSaved += amount
        transfersCount += 1
        storedTotal = totalSaved
        storedTransfers = transfersCount

        // Проверяем достигли ли milestone
        var unlocked = unlockedSet
        for milestone in Milestone.allCases {
            let target = Double(milestone.rawValue)
            if oldTotal < target, totalSaved >= target, !unlocked.contains(milestone.rawValue) {
                unlocked.insert(milestone.rawValue)
                storedMilestonesCSV = unlocked.sorted().map(String.init).joined(separator: ",")
                newlyUnlocked = milestone
                HapticManager.success()
                break
            }
        }
    }

    // MARK: - Milestones

    var unlockedSet: Set<Int> {
        Set(storedMilestonesCSV.split(separator: ",").compactMap { Int($0) })
    }

    var nextMilestone: Milestone? {
        Milestone.allCases.first { Double($0.rawValue) > totalSaved }
    }

    var previousMilestoneAmount: Double {
        let prev = Milestone.allCases.last(where: { Double($0.rawValue) <= totalSaved })
        return prev.map { Double($0.rawValue) } ?? 0
    }

    /// Прогресс к следующему milestone (0..1). Если все достигнуты — 1.
    var progressToNext: Double {
        guard let next = nextMilestone else { return 1.0 }
        let prev = previousMilestoneAmount
        let span = Double(next.rawValue) - prev
        guard span > 0 else { return 1.0 }
        return min(max((totalSaved - prev) / span, 0), 1)
    }

    func acknowledgeUnlock() {
        newlyUnlocked = nil
    }

    // MARK: - Utility

    var hasAnySavings: Bool { totalSaved > 0 }

    var firstUseDate: Date {
        firstUseTimestamp > 0 ? Date(timeIntervalSince1970: firstUseTimestamp) : Date()
    }

    /// Скока дней пользуется minprice (для соц-карточки).
    var daysUsing: Int {
        let secs = Date().timeIntervalSince(firstUseDate)
        return max(1, Int(secs / 86_400))
    }
}
