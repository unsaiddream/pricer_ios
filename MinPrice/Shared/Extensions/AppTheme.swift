import SwiftUI
import UIKit

// MARK: - Elevation
// Single clean shadow, adapts to light/dark. Replaces the old double-shadow
// neumorphic look (too trendy 2020, reads as amateur today).

struct ElevationCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(
                color: scheme == .dark ? .black.opacity(0.45) : .black.opacity(0.06),
                radius: 14, x: 0, y: 6
            )
    }
}

struct ElevationButton: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .shadow(
                color: scheme == .dark ? .black.opacity(0.40) : .black.opacity(0.08),
                radius: 6, x: 0, y: 2
            )
    }
}

extension View {
    func neumorphicCard(radius: CGFloat = 12) -> some View {
        modifier(ElevationCard(radius: radius))
    }
    func neumorphicButton() -> some View {
        modifier(ElevationButton())
    }
}

// MARK: - Brand Gradient (бирюзовый бренд-градиент для заголовков и акцентов)

extension LinearGradient {
    static var brandPrimary: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.45, green: 0.85, blue: 0.95),
                Color(red: 0.07, green: 0.71, blue: 0.84),
                Color(red: 0.05, green: 0.55, blue: 0.70),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var brandShimmer: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.30), .clear],
            startPoint: .top, endPoint: .center
        )
    }
}

// MARK: - Большой заголовок экрана (применяется на главной/каталоге/скидках/избранном/корзине)

struct BrandTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .heavy, design: .rounded))
            .kerning(0.2)
            .foregroundStyle(LinearGradient.brandPrimary)
            .shadow(color: Color.appPrimary.opacity(0.20), radius: 8, x: 0, y: 0)
    }
}

// MARK: - Press-scale button style
// Subtle spring scale-down on press. Applied to NavigationLink-wrapped
// product/category tiles to give tactile feedback.

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressScaleStyle {
    static var pressScale: PressScaleStyle { PressScaleStyle() }
}

// MARK: - Палитра — единый источник правды для всего приложения
//
// Правило: в фичах и компонентах НЕ создавать `Color(red:green:blue:)` напрямую.
// Все цвета берём из этого extension. Бренд-аксенты — из BrandPalette.

extension Color {
    // Primary — cyan/teal как на сайте hsl(195, 85%, 48%)
    static let appPrimary = Color(red: 0.07, green: 0.71, blue: 0.84)
    // Светлый и тёмный концы primary-градиента — выносим, чтобы не дублировать
    static let appPrimaryLight = Color(red: 0.45, green: 0.85, blue: 0.95)
    static let appPrimaryDeep = Color(red: 0.05, green: 0.55, blue: 0.70)

    // Семантика
    static let discountRed = Color(red: 0.88, green: 0.38, blue: 0.45)
    static let discountRedDeep = Color(red: 0.95, green: 0.22, blue: 0.32)
    static let savingsGreen = Color(red: 0.14, green: 0.72, blue: 0.50)
    static let savingsGreenSoft = Color(red: 0.40, green: 0.85, blue: 0.65)
    static let savingsGreenDeep = Color(red: 0.05, green: 0.50, blue: 0.30)
    static let warningAmber = Color(red: 0.96, green: 0.62, blue: 0.16)

    // Текст — адаптивные
    static let appForeground = Color(UIColor.label)
    static let appMuted = Color(UIColor.secondaryLabel)
    static let appSubtle = Color(UIColor.tertiaryLabel)

    // Поверхности — светлее в тёмном режиме чем чисто чёрный
    static let appCard = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.18, blue: 0.21, alpha: 1)
            : UIColor.systemBackground
    })
    // Поднятая поверхность — для слоя над карточкой (модалки, sheets)
    static let appCardElevated = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1)
            : UIColor.systemBackground
    })
    static let appBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
            : UIColor.secondarySystemBackground
    })
    static let appBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.30, alpha: 1)
            : UIColor(red: 0.88, green: 0.90, blue: 0.93, alpha: 1)
    })
    // Бледная разделительная линия (между строками в карточке)
    static let appDivider = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : UIColor(red: 0.93, green: 0.94, blue: 0.96, alpha: 1)
    })
}

// MARK: - Брендовая палитра категорий (для каталога)

enum BrandPalette {
    static let categoryPalette: [Color] = [
        Color(red: 0.95, green: 0.35, blue: 0.35),
        Color(red: 1.00, green: 0.55, blue: 0.15),
        Color(red: 0.25, green: 0.75, blue: 0.40),
        Color(red: 0.20, green: 0.55, blue: 0.95),
        Color(red: 0.60, green: 0.30, blue: 0.90),
        Color(red: 0.95, green: 0.30, blue: 0.65),
        Color(red: 0.10, green: 0.70, blue: 0.75),
        Color(red: 0.40, green: 0.25, blue: 0.85),
        Color(red: 0.85, green: 0.75, blue: 0.10),
        Color(red: 0.20, green: 0.65, blue: 0.55),
        Color(red: 0.50, green: 0.80, blue: 0.25),
        Color(red: 0.55, green: 0.35, blue: 0.20),
    ]

    // Цвета магазинов — используются в графике и легендах.
    // Идентифицируем по chain_slug, потому что Small/Galmart/Toimart
    // имеют общий store_source = "wolt".
    static let mgoRed         = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let arbuzOrange    = Color(red: 1.00, green: 0.55, blue: 0.20)
    static let airbaBlue      = Color(red: 0.30, green: 0.65, blue: 1.00)
    static let smallPurple    = Color(red: 0.70, green: 0.45, blue: 1.00)
    static let galmartGreen   = Color(red: 0.20, green: 0.78, blue: 0.55)  // фирменный зелёный
    static let toimartPink    = Color(red: 1.00, green: 0.42, blue: 0.65)  // тёплый розовый

    /// Цвет сети по chain_slug (приоритет) или store_source (fallback для старых данных).
    /// Сначала смотрим в RemoteConfig (бэк может прислать цвет для новой сети без релиза),
    /// потом в захардкоженный fallback.
    static func storeColor(slug: String?, source: String?) -> Color {
        // 1) Динамическая палитра из RemoteConfig — позволяет добавить новую сеть
        //    с её фирменным цветом не выпуская обновление приложения.
        if let hex = ConfigSnapshot.chainColorHex(slug: slug),
           let remote = Color(hex: hex) {
            return remote
        }
        // 2) Захардкоженные цвета для известных сетей.
        if let s = slug?.lowercased() {
            switch s {
            case "mgo":        return mgoRed
            case "arbuz":      return arbuzOrange
            case "airbafresh": return airbaBlue
            case "small":      return smallPurple
            case "galmart":    return galmartGreen
            case "toimart":    return toimartPink
            default:           break
            }
        }
        switch source?.lowercased() {
        case "mgo":        return mgoRed
        case "arbuz":      return arbuzOrange
        case "airbafresh": return airbaBlue
        case "wolt":       return smallPurple   // дефолт когда slug не пришёл
        default:           return .appPrimaryLight
        }
    }

    /// Старая сигнатура для обратной совместимости (только source).
    @available(*, deprecated, message: "Use storeColor(slug:source:) instead")
    static func storeColor(for source: String) -> Color {
        storeColor(slug: nil, source: source)
    }
}

// MARK: - Hex parsing для цветов из RemoteConfig

extension Color {
    /// Парсит "#RRGGBB" / "RRGGBB" / "#RRGGBBAA" из конфига.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let val = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((val >> 16) & 0xFF) / 255.0
            g = Double((val >>  8) & 0xFF) / 255.0
            b = Double( val        & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((val >> 24) & 0xFF) / 255.0
            g = Double((val >> 16) & 0xFF) / 255.0
            b = Double((val >>  8) & 0xFF) / 255.0
            a = Double( val        & 0xFF) / 255.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Дополнительные градиенты

extension LinearGradient {
    static var brandSavings: LinearGradient {
        LinearGradient(
            colors: [.savingsGreenSoft, .savingsGreen, .savingsGreenDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static var brandDanger: LinearGradient {
        LinearGradient(
            colors: [Color.discountRed.opacity(0.95), .discountRedDeep],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Фон главной — светлый и тёмный варианты (используется в HomeView)
    static func homeBackground(isDark: Bool) -> LinearGradient {
        LinearGradient(
            stops: isDark ? [
                .init(color: Color(red: 0.05, green: 0.18, blue: 0.30), location: 0.0),
                .init(color: Color(red: 0.08, green: 0.22, blue: 0.35), location: 0.35),
                .init(color: Color.appBackground, location: 0.75),
            ] : [
                .init(color: Color(red: 0.82, green: 0.94, blue: 1.0), location: 0.0),
                .init(color: Color(red: 0.88, green: 0.96, blue: 1.0), location: 0.35),
                .init(color: Color.appBackground, location: 0.75),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // Тёмный фон чарта корзины
    static var chartDark: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.10, blue: 0.16),
                Color(red: 0.06, green: 0.18, blue: 0.26),
                Color(red: 0.04, green: 0.16, blue: 0.22),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}
