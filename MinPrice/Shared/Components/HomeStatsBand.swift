import SwiftUI

/// Hero статистика-полоса на главной — trading-floor дашборд:
/// "Сегодня средняя экономия −15.4%", "234 движения цен", "max −68%".
/// JetBrains Mono на цифрах + большая зелёная стрелка ▼.
struct HomeStatsBand: View {
    let bestDeals: [Product]
    let priceDrops: [Product]

    private struct Stats {
        let avgPercent: Double
        let movementsCount: Int
        let maxPercent: Int
    }

    private var stats: Stats? {
        let combined = bestDeals + priceDrops
        guard !combined.isEmpty else { return nil }

        let percents: [Double] = combined.compactMap { p in
            if let pct = p.priceRange?.savingsPercent, pct > 0 { return pct }
            if let stores = p.stores,
               let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
               let prev = best.previousPrice, prev > best.price {
                return ((prev - best.price) / prev) * 100
            }
            return nil
        }
        guard !percents.isEmpty else { return nil }

        let avg = percents.reduce(0, +) / Double(percents.count)
        let max = Int(percents.max() ?? 0)
        return Stats(avgPercent: avg, movementsCount: percents.count, maxPercent: max)
    }

    var body: some View {
        if let s = stats {
            content(s)
        }
    }

    private func content(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Eyebrow
            HStack(spacing: 6) {
                LiveDot(color: .savingsGreen, size: 5)
                Text("СЕГОДНЯ ВЫГОДНО")
                    .font(.mono(9, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Color.appMuted)
            }

            // Главное число — большое, моноширинное, со стрелкой
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("▼")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color.savingsGreen)
                Text("−\(String(format: "%.1f", s.avgPercent))%")
                    .font(.mono(34, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: s.avgPercent)
                Spacer(minLength: 0)
            }

            Text("Средняя скидка по выгодным предложениям")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.appMuted)

            Divider().overlay(Color.appBorder)

            // Stat-row: движения цен + max скидка
            HStack(spacing: 0) {
                statColumn(
                    label: "ДВИЖЕНИЙ",
                    value: "\(s.movementsCount)",
                    valueColor: Color.appForeground
                )
                Divider()
                    .frame(height: 32)
                    .overlay(Color.appBorder)
                statColumn(
                    label: "МАКС СКИДКА",
                    value: "−\(s.maxPercent)%",
                    valueColor: Color.discountRed
                )
            }
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.6)
        )
    }

    private func statColumn(label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.mono(8, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(Color.appMuted)
            Text(value)
                .font(.mono(18, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}
