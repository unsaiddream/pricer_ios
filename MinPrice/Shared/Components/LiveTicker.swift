import SwiftUI

/// Бегущая строка top-deals на главной — "trading floor" сигнатура нашего UI.
/// Прокручивается справа налево бесконечно. Прайсы в JetBrains Mono,
/// дельты с ▲▼. Создаёт ощущение реальной торговой ленты.
struct LiveTicker: View {
    let products: [Product]
    var speed: CGFloat = 28  // pt/sec

    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var didMeasure = false

    private var entries: [TickerEntry] {
        products.prefix(20).compactMap { p in
            guard let cheapest = p.cheapestPrice else { return nil }
            let stores = p.stores ?? []
            let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price })
            let pct: Int? = {
                if let prev = best?.previousPrice, let cur = best?.price, prev > cur {
                    return Int(((prev - cur) / prev) * 100)
                }
                if let saving = p.priceRange?.savingsPercent, saving > 0 {
                    return Int(saving)
                }
                return nil
            }()
            return TickerEntry(
                id: p.uuid,
                title: shortName(p.title),
                price: cheapest,
                deltaPct: pct
            )
        }
    }

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            tickerView
        }
    }

    private var tickerView: some View {
        GeometryReader { geo in
            // Дублируем содержимое — вторая копия следует за первой,
            // когда первая ушла за левый край, начинаем offset с -contentWidth → 0.
            HStack(spacing: 24) {
                tickerStrip
                tickerStrip
            }
            .fixedSize()
            .offset(x: offset)
            .onAppear {
                // Подождём пока контент отрисуется и измерится
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if contentWidth > 0 {
                        startScrolling()
                    }
                }
            }
            .background(
                GeometryReader { inner in
                    Color.clear
                        .onAppear {
                            // Ширина одной полосы — половина общего HStack
                            let w = inner.size.width / 2
                            if !didMeasure, w > 0 {
                                didMeasure = true
                                contentWidth = w
                                offset = 0
                                startScrolling()
                            }
                        }
                }
            )
            .frame(width: geo.size.width, alignment: .leading)
            .clipped()
        }
        .frame(height: 28)
        .background(
            // Тёмная "лента" — terminal-style, с лёгкой подсветкой по краям
            ZStack {
                Color.appForeground.opacity(0.92)
                LinearGradient(
                    colors: [.clear, Color.appForeground.opacity(0), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        )
        .overlay(
            // Fade-out маски слева и справа — чтобы ticker уходил за края мягко
            HStack {
                LinearGradient(
                    colors: [Color.appForeground.opacity(0.92), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 24)
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.appForeground.opacity(0.92)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 24)
            }
            .allowsHitTesting(false)
        )
    }

    private var tickerStrip: some View {
        HStack(spacing: 24) {
            ForEach(entries) { entry in
                tickerItem(entry)
            }
        }
        .padding(.horizontal, 16)
    }

    private func tickerItem(_ entry: TickerEntry) -> some View {
        HStack(spacing: 6) {
            Text(entry.title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appBackground.opacity(0.85))
                .lineLimit(1)

            Text(formatPriceTg(entry.price))
                .font(.mono(11, weight: .semibold))
                .foregroundStyle(Color.appBackground)

            if let pct = entry.deltaPct, pct > 0 {
                HStack(spacing: 1) {
                    Text("▼")
                        .font(.system(size: 8, weight: .black))
                    Text("\(pct)%")
                        .font(.mono(10, weight: .bold))
                }
                .foregroundStyle(Color.savingsGreen)
            }
        }
    }

    private func startScrolling() {
        guard contentWidth > 0 else { return }
        let duration = Double(contentWidth / speed)
        offset = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -contentWidth - 24
        }
    }

    /// Сокращаем имя товара до первых 3-4 значимых слов — иначе ticker засоряется.
    private func shortName(_ s: String) -> String {
        let words = s.components(separatedBy: " ")
        guard words.count > 4 else { return s }
        return words.prefix(3).joined(separator: " ") + "…"
    }
}

private struct TickerEntry: Identifiable {
    let id: String
    let title: String
    let price: Double
    let deltaPct: Int?
}

// MARK: - LIVE pulsing dot

/// Маленький пульсирующий зелёный индикатор "live data". Парный к надписи
/// чтобы создать ощущение что данные обновляются в реальном времени.
struct LiveDot: View {
    var color: Color = .savingsGreen
    var size: CGFloat = 6

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Пульсирующий ореол вокруг точки
            Circle()
                .fill(color.opacity(0.5))
                .frame(width: size * (pulse ? 2.6 : 1), height: size * (pulse ? 2.6 : 1))
                .opacity(pulse ? 0 : 0.7)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.7), radius: 3, x: 0, y: 0)
        }
        .frame(width: size * 2.6, height: size * 2.6)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Price delta badge

/// Стрелка ▼ или ▲ с процентом — для трейдер-стиля изменения цены.
/// В отличие от DiscountChip (большой красный) — этот маленький, моноширинный,
/// для inline-показа в карточках и списках.
struct PriceDeltaBadge: View {
    let percent: Int
    /// true — цена выросла (плохо для покупателя, красным),
    /// false — упала (хорошо, зелёным)
    let isUp: Bool

    var body: some View {
        HStack(spacing: 1) {
            Text(isUp ? "▲" : "▼")
                .font(.system(size: 8, weight: .black))
            Text("\(abs(percent))%")
                .font(.mono(10, weight: .bold))
        }
        .foregroundStyle(isUp ? Color.discountRed : Color.savingsGreen)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            (isUp ? Color.discountRed : Color.savingsGreen).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 4)
        )
    }
}
