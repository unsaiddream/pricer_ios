import SwiftUI

extension Color {
    // Primary — cyan/teal как на сайте hsl(195, 85%, 48%)
    static let appPrimary = Color(red: 0.07, green: 0.71, blue: 0.84)

    // Бейджи
    static let discountRed = Color(red: 0.95, green: 0.13, blue: 0.13)
    static let savingsGreen = Color(red: 0.08, green: 0.63, blue: 0.35)

    // Текст — адаптивные
    static let appForeground = Color(UIColor.label)
    static let appMuted = Color(UIColor.secondaryLabel)

    // Поверхности — адаптивные
    static let appCard = Color(UIColor.systemBackground)
    static let appBackground = Color(UIColor.secondarySystemBackground)
    static let appBorder = Color(UIColor.separator)
}
