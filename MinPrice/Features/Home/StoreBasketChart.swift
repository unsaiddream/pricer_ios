import SwiftUI
import Charts

// MARK: - Магазины (6 поддерживаемых сетей; идентификация по chain_slug)
// Small/Galmart/Toimart разделяют один store_source = "wolt", поэтому
// сеть нужно различать по chain_slug, а не по source.

private let basketKnownSlugs: [String] = ["mgo", "arbuz", "airbafresh", "small", "galmart", "toimart"]

/// Канонический ключ сети из chain_slug (приоритет) или из chain_name/source как fallback.
private func basketCanonicalSlug(slug: String?, name: String?, source: String?) -> String? {
    if let s = slug?.lowercased(), basketKnownSlugs.contains(s) { return s }
    // Фоллбек по нормализованному chain_name (на случай старых ответов без slug)
    let raw = (name ?? source ?? "").lowercased()
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: ".", with: "")
    if raw.contains("galmart")                                            { return "galmart" }
    if raw.contains("toimart") || raw.contains("toi")                     { return "toimart" }
    if raw.contains("magnum") || raw == "mgo" || raw.contains("magnumgo") { return "mgo" }
    if raw.contains("airba") || raw.contains("fresh")                     { return "airbafresh" }
    if raw.contains("arbuz")                                              { return "arbuz" }
    if raw.contains("small")                                              { return "small" }
    if raw == "wolt"                                                      { return "small" } // legacy
    return nil
}

private func basketChartColor(_ slug: String) -> Color {
    BrandPalette.storeColor(slug: slug, source: nil)
}

private func basketStoreLabel(_ slug: String) -> String {
    switch slug {
    case "mgo":         return "MagnumGO"
    case "arbuz":       return "Arbuz.kz"
    case "airbafresh":  return "AirbaFresh"
    case "small":       return "SMALL"
    case "galmart":     return "Galmart"
    case "toimart":     return "Toimart"
    default:            return slug
    }
}

/// Локальный ассет — fallback на случай если chain_logo с бэка не загрузился.
private func basketStoreAsset(_ slug: String) -> String? {
    switch slug {
    case "mgo":         return "store_magnum"
    case "arbuz":       return "store_arbuz"
    case "airbafresh":  return "store_airba_fresh"
    case "small":       return "store_small"
    // galmart/toimart — без локального ассета, рендерим chain_logo через KFImage
    default:            return nil
    }
}

// Лого с прозрачным фоном — нужна белая подложка и `scaledToFit`.
private func basketLogoNeedsWhiteBg(_ slug: String) -> Bool {
    slug == "airbafresh" || slug == "small" || slug == "galmart" || slug == "toimart"
}

// MARK: - Период

enum BasketPeriod: String, CaseIterable, Identifiable {
    case now      // сейчас — текущие цены
    case month    // месяц — среднее между current и previousPrice
    case quarter  // 3 месяца — previousPrice (или current если нет)

    var id: String { rawValue }
    var label: String {
        switch self {
        case .now:     return "1 день"
        case .month:   return "30 дней"
        case .quarter: return "90 дней"
        }
    }

    /// Сколько дней назад была "опорная" цена (previousPrice)
    var anchorDaysAgo: Int {
        switch self {
        case .now:     return 1
        case .month:   return 30
        case .quarter: return 90
        }
    }
}

// MARK: - Режим отображения

enum BasketViewMode: String, CaseIterable {
    case bars
    case line
}

// MARK: - Модель строки графика

struct StoreBasketColumn: Identifiable {
    let id = UUID()
    let source: String
    let average: Double          // средняя цена товара в этом магазине
    let basketTotal: Double      // сумма цен по всем товарам пересечения
    let wins: Int                // сколько раз магазин был самым дешёвым
    let winShare: Double         // % побед — для контекста под лого
    let honestyScore: Double     // главная метрика — 0..100 (выше = выгоднее)
    let overpayPercent: Double   // средняя переплата vs минимума (0..100+)
    let coveredCount: Int        // в скольки товарах магазин участвует
    let hasData: Bool
}

// MARK: - Компонент

struct StoreBasketChart: View {
    let category: Category?
    /// Готовый агрегат с бэка — приоритетный источник.
    /// Если nil, используется legacy-путь через products + клиентский precompute.
    let summary: StoreBasketResponse?
    let products: [Product]

    @State private var period: BasketPeriod = .now
    @State private var viewMode: BasketViewMode = .bars
    @State private var showsFormula = false
    @State private var shareItem: BasketShareItem?

    // Кэш для legacy-пути (когда нет summary)
    @State private var cachedColumns: [StoreBasketColumn] = []
    @State private var cachedCoverageCount: Int = 0

    init(category: Category?, summary: StoreBasketResponse? = nil, products: [Product] = []) {
        self.category = category
        self.summary = summary
        self.products = products
    }

    /// Колонки — берём из агрегата с бэка, если есть; иначе из локального precompute.
    private var columns: [StoreBasketColumn] {
        if let s = summary {
            return s.columns.map { col in
                StoreBasketColumn(
                    source: col.slug,
                    average: col.average,
                    basketTotal: col.basketTotal,
                    wins: col.wins,
                    winShare: col.winShare,
                    honestyScore: col.honestyScore,
                    overpayPercent: col.overpayPercent,
                    coveredCount: col.coveredCount,
                    hasData: col.hasData
                )
            }
        }
        return cachedColumns
    }
    private var coverageCount: Int {
        summary?.coverageCount ?? cachedCoverageCount
    }

    /// Только для legacy-пути.
    private func recomputeCache() {
        guard summary == nil else { return }
        let result = StoreBasketChart.precompute(products: products, period: period)
        cachedColumns = result.columns
        cachedCoverageCount = result.coverageCount
    }

    // Высота столбика — Honesty Score (0..100), главная метрика.
    private func barRatio(_ col: StoreBasketColumn) -> Double {
        guard col.hasData else { return 0 }
        let raw = col.honestyScore / 100  // 0..1
        return max(0.08, raw)
    }

    // Лидер — у кого выше всего Honesty Score
    private var leaderSource: String? {
        let valid = columns.filter(\.hasData)
        guard let top = valid.max(by: { $0.honestyScore < $1.honestyScore }), top.honestyScore > 0 else { return nil }
        return top.source
    }

    // Бейдж в шапке: разрыв в баллах между лучшим и худшим магазином.
    // Чем больше разрыв — тем выгоднее покупать у лидера.
    private var leaderAdvantage: Int? {
        let scores = columns.filter(\.hasData).map(\.honestyScore)
        guard let max = scores.max(), let min = scores.min(), max - min >= 5 else { return nil }
        return Int((max - min).rounded())
    }

    private var greenSoft: Color { Color(red: 0.35, green: 0.85, blue: 0.55) }
    private var savingsGreen: Color { Color.savingsGreen }
    private var greenDeep: Color { Color(red: 0.04, green: 0.55, blue: 0.30) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if showsFormula {
                formulaInfo
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
            HStack(spacing: 8) {
                periodSwitcher
                viewModeToggle
            }
            Group {
                switch viewMode {
                case .bars: chartArea
                case .line: lineChartArea
                }
            }
        }
        .padding(16)
        .background {
            DarkChartBackground()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.appPrimary.opacity(0.18), radius: 18, x: 0, y: 6)
        .compositingGroup()
        .onAppear { if cachedColumns.isEmpty { recomputeCache() } }
        .onChange(of: products.map(\.uuid)) { _ in recomputeCache() }
        .onChange(of: period) { _ in recomputeCache() }
        .sheet(item: $shareItem) { item in
            BasketSharePreviewSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @MainActor
    private func generateShareItem() {
        let card = BasketShareCard(
            categoryName: category?.name ?? "Все каталоги",
            categoryEmoji: category?.emoji,
            columns: columns,
            coverageCount: coverageCount,
            period: period,
            viewMode: viewMode,
            linePoints: linePoints
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else { return }
        shareItem = BasketShareItem(image: image)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.40))
                        .frame(width: 30, height: 30)
                        .blur(radius: 8)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appPrimaryLight, Color.appPrimary],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(.white.opacity(0.30), lineWidth: 0.6))
                    if let emoji = category?.emoji, !emoji.isEmpty {
                        Text(emoji).font(.system(size: 14))
                    } else {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(category?.name ?? "Сравнение цен")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(subtitleText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .kerning(0.3)
                            .lineLimit(1)
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) { showsFormula.toggle() }
                        } label: {
                            Image(systemName: showsFormula ? "info.circle.fill" : "info.circle")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(showsFormula ? Color.appPrimary : .white.opacity(0.55))
                        }
                        .buttonStyle(.plain)

                        Button {
                            generateShareItem()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Бейдж: разрыв лидера vs худшего в баллах.
            // Большой разрыв = чёткий лидер; маленький = магазины близки.
            if let gap = leaderAdvantage {
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .black))
                    Text("+\(gap)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background {
                    ZStack {
                        LinearGradient(
                            colors: [greenSoft, savingsGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        LinearGradient(
                            colors: [.white.opacity(0.30), .clear],
                            startPoint: .top, endPoint: .center
                        )
                    }
                    .clipShape(Capsule())
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6))
                .shadow(color: savingsGreen.opacity(0.45), radius: 6, x: 0, y: 2)
            }
        }
    }

    private var subtitleText: String {
        if coverageCount > 0 {
            return "Сравнение по \(coverageCount) \(productsWord(coverageCount))"
        }
        return "Сравнение по 4 магазинам"
    }

    // MARK: Period switcher

    private var periodSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(BasketPeriod.allCases) { p in
                let isSelected = (period == p)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { period = p }
                } label: {
                    Text(p.label)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if isSelected {
                                ZStack {
                                    LinearGradient(
                                        colors: [
                                            Color.appPrimaryLight,
                                            Color.appPrimary,
                                            Color.appPrimaryDeep,
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                    LinearGradient(
                                        colors: [.white.opacity(0.25), .clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                }
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
                                .shadow(color: Color.appPrimary.opacity(0.40), radius: 6, x: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            Capsule().fill(.white.opacity(0.06))
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: Formula info (как считается метрика)

    private var formulaInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.appPrimary)
                Text("Как считаем — полная методика")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(0.3)
                    .foregroundStyle(.white.opacity(0.95))
            }

            // Цель
            formulaSection(
                number: "0",
                title: "Цель",
                body: "Показать, какой магазин в этом каталоге чаще выгоднее всего — и насколько."
            )

            // Шаг 1
            formulaSection(
                number: "1",
                title: "Какие товары попадают в сравнение",
                body: "Берём только те товары, которые продаются минимум в 2 из 4 магазинов. Если товара нет в магазине — он просто не считается этому магазину в плюс или минус. Так SMALL не штрафуется за отсутствие молока."
            )

            // Шаг 2
            formulaSection(
                number: "2",
                title: "Считаем баллы за каждый товар",
                body: "Для каждого товара смотрим самую низкую и самую высокую цену среди магазинов. Магазин с минимальной ценой получает 100 баллов за товар, с максимальной — 0, остальные пропорционально между ними."
            )
            formulaCode("score = (max − price) ÷ (max − min) × 100")

            // Шаг 3
            formulaSection(
                number: "3",
                title: "Усредняем по магазину",
                body: "Считаем среднее по всем товарам, где магазин представлен. Получаем «сырую оценку» магазина."
            )
            formulaCode("raw = среднее(score₁, score₂, ...)")

            // Шаг 4
            formulaSection(
                number: "4",
                title: "Защита от выбросов (Bayesian smoothing)",
                body: "Магазин с 3 товарами и 100 баллами не должен обгонять магазин с 50 товарами и 80. Подмешиваем нейтральные 50 баллов с весом 5 товаров."
            )
            formulaCode("score = (raw × n + 50 × 5) ÷ (n + 5)")

            // Финальные бейджи
            formulaSection(
                number: "5",
                title: "Что показывают бейджи",
                body: "Высота столбика — итоговый балл (0–100). Под лого — «X из Y дешевле всех». Зелёный бейдж сверху ⚡+N — разрыв между лучшим и худшим магазином в баллах: чем больше, тем важнее выбрать правильный магазин."
            )

            // Пример
            VStack(alignment: .leading, spacing: 4) {
                Text("Пример")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .kerning(0.6)
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.55))
                Text("Молоко: A=300₸, B=350₸, C=400₸. Минимум 300, максимум 400, разница 100₸. A получает 100 баллов, B — 50, C — 0. Магазин A в этом товаре выглядит идеально, B — посередине.")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.10), .white.opacity(0.02)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(red: 0.35, green: 0.85, blue: 0.55).opacity(0.18), lineWidth: 0.6)
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [.white.opacity(0.08), .white.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.6)
        )
    }

    private func formulaSection(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Кружок с номером шага
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appPrimaryLight,
                                Color.appPrimary,
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text(number)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 16, height: 16)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Text(body)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private func formulaCode(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
            .foregroundColor(Color(red: 0.55, green: 0.92, blue: 0.95))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Color.white.opacity(0.05)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.appPrimary.opacity(0.20), lineWidth: 0.5)
            )
            .padding(.leading, 24)
    }

    private func formulaLine(icon: String, iconColor: Color, bold: String, rest: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(iconColor)
                .frame(width: 12, height: 12)
                .padding(.top, 3)
            (
                Text(bold).font(.system(size: 10.5, weight: .black, design: .rounded)).foregroundColor(.white)
                + Text(rest).font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.65))
            )
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
        }
    }

    // MARK: View-mode toggle (bars / line)

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            ForEach([BasketViewMode.bars, .line], id: \.self) { mode in
                let isSelected = (viewMode == mode)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { viewMode = mode }
                } label: {
                    Image(systemName: mode == .bars ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                        .frame(width: 34, height: 26)
                        .background {
                            if isSelected {
                                LinearGradient(
                                    colors: [
                                        Color.appPrimaryLight,
                                        Color.appPrimary,
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.appPrimary.opacity(0.35), radius: 5, x: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            Capsule().fill(.white.opacity(0.06))
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: Line chart (как на странице товара)

    fileprivate struct LinePoint: Identifiable {
        let id = UUID()
        let source: String
        let label: String
        let date: Date
        let price: Double
    }

    /// Точки для line-чарта. Приоритет — серверные (`summary.linePoints`),
    /// иначе пересчёт на клиенте.
    private var linePoints: [LinePoint] {
        if let s = summary {
            return s.linePoints.map {
                LinePoint(source: $0.slug, label: basketStoreLabel($0.slug), date: $0.date, price: $0.price)
            }
        }
        return StoreBasketChart.buildLinePoints(products: products, period: period)
    }

    private var lineChartArea: some View {
        Chart {
            ForEach(linePoints) { p in
                LineMark(
                    x: .value("Дата", p.date),
                    y: .value("Цена", p.price),
                    series: .value("Магазин", p.label)
                )
                .foregroundStyle(basketChartColor(p.source))
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                    .foregroundStyle(.white.opacity(0.10))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                    .foregroundStyle(.white.opacity(0.10))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatCompactPrice(v))
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.top, 4)
        .overlay(alignment: .bottom) {
            // Легенда — пилюли с цветами магазинов
            HStack(spacing: 6) {
                ForEach(columns) { col in
                    if col.hasData {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(basketChartColor(col.source))
                                .frame(width: 6, height: 6)
                            Text(basketStoreLabel(col.source))
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 2.5)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }
            }
            .offset(y: 32)
        }
    }

    private func formatCompactPrice(_ v: Double) -> String {
        if v >= 1000 {
            return "\(Int(v / 1000))k"
        }
        return "\(Int(v))"
    }

    // MARK: Chart (bars)

    private var chartArea: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(columns) { col in
                BasketColumn(
                    column: col,
                    isLeader: col.source == leaderSource,
                    ratio: barRatio(col)
                )
            }
        }
        .frame(height: 220)
    }

    private func productsWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "товаров" }
        if m10 == 1 { return "товара" }
        if m10 >= 2 && m10 <= 4 { return "товаров" }
        return "товаров"
    }

    // MARK: - Pure pre-compute (быстро, не зависит от View-state)

    /// Применяет период-эвристику к цене:
    /// - .now      — текущая `price`
    /// - .month    — `(price + previousPrice) / 2` (среднее за период)
    /// - .quarter  — `previousPrice ?? price` (опорная цена до текущих скидок)
    private static func priceForPeriod(price: Double, prev: Double?, period: BasketPeriod) -> Double {
        switch period {
        case .now:
            return price
        case .month:
            if let prev, prev > 0 { return (price + prev) / 2 }
            return price
        case .quarter:
            if let prev, prev > 0 { return prev }
            return price
        }
    }

    static func precompute(products: [Product], period: BasketPeriod = .now) -> (columns: [StoreBasketColumn], coverageCount: Int) {
        // Сборка цен:
        // 1) Сначала пытаемся product.stores (детальный список).
        // 2) Если пусто — fallback на priceRange.stores.
        // 3) Если inStock = false, всё равно учитываем (в feed может приходить без флага).
        let perProduct: [[String: Double]] = products.map { product in
            var d: [String: Double] = [:]

            for s in product.stores ?? [] {
                guard s.price > 0 else { continue }
                guard let key = basketCanonicalSlug(slug: s.chainSlug, name: s.chainName, source: s.storeSource) else { continue }
                if s.inStock == false && d[key] != nil { continue }
                let value = priceForPeriod(price: s.price, prev: s.previousPrice, period: period)
                if let existing = d[key] { d[key] = min(existing, value) }
                else { d[key] = value }
            }

            // Подберём недостающие из priceRange.stores
            for r in product.priceRange?.stores ?? [] {
                guard r.price > 0 else { continue }
                guard let key = basketCanonicalSlug(slug: r.chainSlug, name: r.chainName, source: r.storeSource) else { continue }
                if r.inStock == false && d[key] != nil { continue }
                let value = priceForPeriod(price: r.price, prev: r.previousPrice, period: period)
                if let existing = d[key] { d[key] = min(existing, value) }
                else { d[key] = value }
            }

            return d
        }

        // ── База: товары, доступные хотя бы в 2 магазинах (можно сравнивать) ──
        let coverage: [[String: Double]] = perProduct.filter { dict in
            dict.filter { basketKnownSlugs.contains($0.key) }.count >= 2
        }
        let coverageCount = coverage.count

        // ── Аккумуляторы ──
        var totals: [String: Double] = [:]
        var counts: [String: Int] = [:]
        var wins: [String: Int] = [:]
        var overpayBuckets: [String: [Double]] = [:]
        var scoreBuckets: [String: [Double]] = [:]   // линейно нормализованные оценки 0..100

        for dict in coverage {
            // Только участвующие магазины
            let prices = dict.filter { basketKnownSlugs.contains($0.key) }
            guard let minPrice = prices.values.min(),
                  let maxPrice = prices.values.max(),
                  minPrice > 0 else { continue }

            let range = maxPrice - minPrice
            let winners = prices.filter { $0.value == minPrice }.map(\.key)

            for (src, price) in prices {
                totals[src, default: 0] += price
                counts[src, default: 0] += 1

                if winners.contains(src) {
                    wins[src, default: 0] += 1
                }

                // Линейная нормализация по диапазону цен товара:
                // самый дешёвый = 100, самый дорогой = 0, между ними — пропорционально.
                // Это учитывает РАЗМЕР скидки, а не просто факт победы.
                let normalized: Double
                if range <= 0 {
                    normalized = 50  // все цены равны — нейтрально
                } else {
                    normalized = (maxPrice - price) / range * 100
                }
                scoreBuckets[src, default: []].append(normalized)

                // Также копим переплату в % для метаданных
                let overpay = (price - minPrice) / minPrice * 100
                overpayBuckets[src, default: []].append(overpay)
            }
        }

        // ── Bayesian smoothing — устойчивость к маленькому ассортименту ──
        // Подмешиваем «нейтральные 50 баллов» с весом SMOOTHING товаров.
        // Это значит: магазин с 3 товарами и 100 баллами не обгонит магазин с 50 товарами и 80 баллами.
        let SMOOTHING: Double = 5
        let NEUTRAL_SCORE: Double = 50

        let cols = basketKnownSlugs.map { src -> StoreBasketColumn in
            let count = counts[src] ?? 0
            let total = totals[src] ?? 0
            let avg = count > 0 ? total / Double(count) : 0
            let w = wins[src] ?? 0
            let winShare = count > 0 ? Double(w) / Double(count) * 100 : 0
            let overBucket = overpayBuckets[src] ?? []
            let overAvg = overBucket.isEmpty ? 0 : overBucket.reduce(0, +) / Double(overBucket.count)

            // Honesty Score — главная метрика
            let scores = scoreBuckets[src] ?? []
            let rawScore = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let cD = Double(count)
            let smoothedScore = count > 0
                ? (rawScore * cD + NEUTRAL_SCORE * SMOOTHING) / (cD + SMOOTHING)
                : 0

            return StoreBasketColumn(
                source: src,
                average: avg,
                basketTotal: total,
                wins: w,
                winShare: winShare,
                honestyScore: smoothedScore,
                overpayPercent: overAvg,
                coveredCount: count,
                hasData: count > 0
            )
        }

        return (cols, coverageCount)
    }

    /// Точки для line-chart: 3 точки на магазин (старт периода, середина, сейчас).
    /// Цены строятся из `previousPrice` / `price` товаров через те же эвристики.
    fileprivate static func buildLinePoints(products: [Product], period: BasketPeriod) -> [LinePoint] {
        // 1) Соберём для каждого магазина два списка: старые (previousPrice) и текущие (price).
        var prevByStore: [String: [Double]] = [:]
        var currByStore: [String: [Double]] = [:]

        func add(_ d: inout [String: [Double]], _ key: String, _ v: Double) {
            if v > 0 { d[key, default: []].append(v) }
        }

        for product in products {
            for s in product.stores ?? [] {
                guard let key = basketCanonicalSlug(slug: s.chainSlug, name: s.chainName, source: s.storeSource) else { continue }
                add(&currByStore, key, s.price)
                if let prev = s.previousPrice { add(&prevByStore, key, prev) }
            }
            for r in product.priceRange?.stores ?? [] {
                guard let key = basketCanonicalSlug(slug: r.chainSlug, name: r.chainName, source: r.storeSource) else { continue }
                add(&currByStore, key, r.price)
                if let prev = r.previousPrice { add(&prevByStore, key, prev) }
            }
        }

        // 2) Усредняем
        func avg(_ a: [Double]) -> Double? { a.isEmpty ? nil : a.reduce(0, +) / Double(a.count) }

        // 3) Даты: now, mid, anchor (anchorDaysAgo)
        let now = Date()
        let cal = Calendar.current
        let anchor = cal.date(byAdding: .day, value: -period.anchorDaysAgo, to: now) ?? now
        let mid = cal.date(byAdding: .day, value: -period.anchorDaysAgo / 2, to: now) ?? now

        var result: [LinePoint] = []
        for src in basketKnownSlugs {
            let label = basketStoreLabel(src)
            let curr = avg(currByStore[src] ?? [])
            let prev = avg(prevByStore[src] ?? []) ?? curr
            guard let currVal = curr else { continue }
            let prevVal = prev ?? currVal
            let midVal = (currVal + prevVal) / 2

            result.append(LinePoint(source: src, label: label, date: anchor, price: prevVal))
            result.append(LinePoint(source: src, label: label, date: mid,    price: midVal))
            result.append(LinePoint(source: src, label: label, date: now,    price: currVal))
        }
        return result
    }
}

// MARK: - Single column (vertical bar)

private struct BasketColumn: View {
    let column: StoreBasketColumn
    let isLeader: Bool
    let ratio: Double

    private var greenSoft: Color { Color(red: 0.35, green: 0.85, blue: 0.55) }
    private var savingsGreen: Color { Color.savingsGreen }
    private var greenDeep: Color { Color(red: 0.04, green: 0.55, blue: 0.30) }

    var body: some View {
        VStack(spacing: 6) {
            // Сверху — Honesty Score (главная метрика, 0..100 баллов)
            Group {
                if column.hasData {
                    Text("\(Int(column.honestyScore.rounded()))")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(
                            isLeader
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        colors: [greenSoft, savingsGreen, greenDeep],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                  )
                                : AnyShapeStyle(Color.white.opacity(0.92))
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.30))
                }
            }
            .frame(height: 22)

            // Сам столбец
            GeometryReader { geo in
                let availableHeight = geo.size.height
                let barHeight = max(8, availableHeight * ratio)
                ZStack(alignment: .bottom) {
                    // Трэк (placeholder)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.04))
                        .frame(maxWidth: .infinity)

                    if column.hasData {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                isLeader
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [greenSoft, savingsGreen, greenDeep],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                      )
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                basketChartColor(column.source).opacity(1.0),
                                                basketChartColor(column.source).opacity(0.65),
                                            ],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                      )
                            )
                            .overlay(
                                // Шиммер сверху бара
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.30), .clear],
                                            startPoint: .top, endPoint: .center
                                        )
                                    )
                            )
                            .frame(height: barHeight)
                            .overlay(alignment: .top) {
                                if isLeader {
                                    Text("min")
                                        .font(.system(size: 8, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .kerning(0.4)
                                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                                        .background {
                                            LinearGradient(
                                                colors: [greenSoft, savingsGreen],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                            .clipShape(Capsule())
                                        }
                                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.4))
                                        .shadow(color: savingsGreen.opacity(0.45), radius: 4, x: 0, y: 1)
                                        .offset(y: -10)
                                }
                            }
                    }
                }
            }

            // Нижняя плашка с лого + лейблом
            VStack(spacing: 4) {
                Group {
                    if let asset = basketStoreAsset(column.source), UIImage(named: asset) != nil {
                        if basketLogoNeedsWhiteBg(column.source) {
                            // AirbaFresh — прозрачный лого, нужна белая подложка
                            ZStack {
                                Color.white
                                Image(asset)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(2.5)
                            }
                        } else {
                            // Magnum/Arbuz/SMALL — full-bleed
                            Image(asset)
                                .resizable()
                                .scaledToFill()
                        }
                    } else {
                        ZStack {
                            Color.white
                            Text(String(basketStoreLabel(column.source).prefix(1)))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(basketChartColor(column.source))
                        }
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                )
                .opacity(column.hasData ? 1 : 0.45)

                Text(basketStoreLabel(column.source))
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(column.hasData ? 0.85 : 0.40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // «дешевле в X из Y» — где магазин представлен
                if column.hasData && column.coveredCount > 0 {
                    Text("\(column.wins) из \(column.coveredCount)")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func formatPrice(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? String(Int(v))) ₸"
    }
}

// MARK: - Background (вынесен — чтобы не пересчитывался при scroll)

private struct DarkChartBackground: View {
    var body: some View {
        ZStack {
            LinearGradient.chartDark
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.appPrimary.opacity(0.30), .clear],
                            center: .center, startRadius: 0, endRadius: 110
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: -60, y: -50)
                    .blur(radius: 14)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.savingsGreen.opacity(0.28), .clear],
                            center: .center, startRadius: 0, endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .offset(x: geo.size.width - 80, y: geo.size.height - 80)
                    .blur(radius: 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Share

struct BasketShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
    var activityItems: [Any] {
        [image, "Сравнение цен от minprice.kz"]
    }
}

private struct BasketShareCard: View {
    let categoryName: String
    let categoryEmoji: String?
    let columns: [StoreBasketColumn]
    let coverageCount: Int
    let period: BasketPeriod
    let viewMode: BasketViewMode
    let linePoints: [StoreBasketChart.LinePoint]

    private var maxRatio: Double {
        let max = columns.filter(\.hasData).map(\.winShare).max() ?? 1
        return max
    }

    private func barRatio(_ col: StoreBasketColumn) -> Double {
        guard col.hasData else { return 0 }
        let raw = col.winShare / 100
        return Swift.max(0.06, raw)
    }

    private var leaderSource: String? {
        let valid = columns.filter(\.hasData)
        guard let top = valid.max(by: { $0.winShare < $1.winShare }), top.winShare > 0 else { return nil }
        return top.source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                if let img = UIImage(named: "AppLogo") {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(height: 32)
                }
                Text("minprice.kz")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .kerning(-0.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.appPrimaryLight,
                                Color.appPrimary,
                                Color.appPrimaryDeep,
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Spacer()
                Text(period.label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background {
                        LinearGradient(
                            colors: [
                                Color.appPrimaryLight,
                                Color.appPrimary,
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .clipShape(Capsule())
                    }
            }

            // Title
            HStack(spacing: 8) {
                if let emoji = categoryEmoji, !emoji.isEmpty {
                    Text(emoji).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(categoryName)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    if coverageCount > 0 {
                        Text("\(coverageCount) товаров в сравнении")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                Spacer()
            }

            // Body
            switch viewMode {
            case .bars: barsRender
            case .line: linesRender
            }

            // Footer
            HStack {
                Text("Сравнение цен в 4 магазинах Казахстана")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("minprice.kz")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(20)
        .frame(width: 380)
        .background {
            ZStack {
                LinearGradient.chartDark
                GeometryReader { geo in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.appPrimary.opacity(0.30), .clear],
                                center: .center, startRadius: 0, endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                        .offset(x: -60, y: -50)
                        .blur(radius: 14)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.savingsGreen.opacity(0.28), .clear],
                                center: .center, startRadius: 0, endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .offset(x: geo.size.width - 80, y: geo.size.height - 80)
                        .blur(radius: 16)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
    }

    private var barsRender: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(columns) { col in
                BasketColumn(
                    column: col,
                    isLeader: col.source == leaderSource,
                    ratio: barRatio(col)
                )
            }
        }
        .frame(height: 240)
    }

    @ViewBuilder
    private var linesRender: some View {
        Chart {
            ForEach(linePoints) { p in
                LineMark(
                    x: .value("Дата", p.date),
                    y: .value("Цена", p.price),
                    series: .value("Магазин", p.label)
                )
                .foregroundStyle(basketShareLineColor(p.source))
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [2, 3]))
                    .foregroundStyle(.white.opacity(0.10))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v >= 1000 ? "\(Int(v / 1000))k" : "\(Int(v))")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .frame(height: 240)
    }
}

private func basketShareLineColor(_ source: String) -> Color {
    BrandPalette.storeColor(for: source)
}

struct BasketSharePreviewSheet: View {
    let item: BasketShareItem
    @Environment(\.dismiss) private var dismiss
    @State private var savedToast = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(width: 26, height: 26)
                Text("Поделиться графиком")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.brandPrimary)
                    .shadow(color: Color.appPrimary.opacity(0.20), radius: 6, x: 0, y: 0)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            ScrollView {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.appPrimary.opacity(0.30), Color.appPrimary.opacity(0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.appPrimary.opacity(0.18), radius: 22, x: 0, y: 10)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 10) {
                Button {
                    UIImageWriteToSavedPhotosAlbum(item.image, nil, nil, nil)
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { savedToast = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        withAnimation(.easeOut(duration: 0.25)) { savedToast = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: savedToast ? "checkmark.circle.fill" : "arrow.down.to.line")
                            .font(.system(size: 14, weight: .black))
                        Text(savedToast ? "Сохранено" : "Скачать")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .contentTransition(.opacity)
                    }
                    .foregroundStyle(savedToast ? Color.savingsGreen : Color.appPrimary)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background {
                        Capsule().fill((savedToast ? Color.savingsGreen : Color.appPrimary).opacity(0.12))
                    }
                    .overlay(Capsule().strokeBorder((savedToast ? Color.savingsGreen : Color.appPrimary).opacity(0.30), lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Button {
                    let vc = UIActivityViewController(activityItems: item.activityItems, applicationActivities: nil)
                    vc.completionWithItemsHandler = { type, _, _, _ in if type != nil { dismiss() } }
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let root = scene.windows.first?.rootViewController else { return }
                    var top = root
                    while let p = top.presentedViewController { top = p }
                    top.present(vc, animated: true)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .black))
                        Text("Поделиться")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background {
                        ZStack {
                            LinearGradient.brandPrimary
                            LinearGradient.brandShimmer
                        }
                        .clipShape(Capsule())
                    }
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.7))
                    .shadow(color: Color.appPrimary.opacity(0.45), radius: 12, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color.appPrimary.opacity(0.06), Color.appBackground],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}
