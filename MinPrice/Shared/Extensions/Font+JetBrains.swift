import SwiftUI

extension Font {
    /// Системный шрифт rounded — для UI-надписей (заголовки, подписи).
    static func jb(_ size: CGFloat, weight: JBWeight = .medium) -> Font {
        .system(size: size, weight: weight.swiftUIWeight, design: .rounded)
    }

    /// Настоящий JetBrains Mono — моноширинный шрифт для прайсов и чисел.
    /// Trading-floor сигнатура: ВСЕ цены и численные данные идут через mono,
    /// тогда колонки выравниваются по позициям цифр и читаются как биржевая
    /// таблица. Цифры одинаковой ширины — глаз не "прыгает" при тике числа.
    static func mono(_ size: CGFloat, weight: JBWeight = .medium) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "JetBrainsMono-Regular"
        case .medium:   name = "JetBrainsMono-Medium"
        case .semibold: name = "JetBrainsMono-SemiBold"
        case .bold:     name = "JetBrainsMono-Bold"
        }
        return .custom(name, size: size)
    }

    enum JBWeight: String {
        case regular  = "regular"
        case medium   = "medium"
        case semibold = "semibold"
        case bold     = "bold"

        var swiftUIWeight: Font.Weight {
            switch self {
            case .regular:  return .regular
            case .medium:   return .medium
            case .semibold: return .semibold
            case .bold:     return .bold
            }
        }
    }
}
