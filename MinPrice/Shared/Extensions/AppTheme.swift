import SwiftUI

extension Color {
    // Primary — cyan/teal как на сайте hsl(195, 85%, 48%)
    static let appPrimary = Color(red: 0.07, green: 0.71, blue: 0.84)

    // Бейджи
    static let discountRed = Color(red: 0.95, green: 0.13, blue: 0.13)
    static let savingsGreen = Color(red: 0.08, green: 0.63, blue: 0.35)

    // Текст
    static let appForeground = Color(red: 0.07, green: 0.11, blue: 0.20)
    static let appMuted = Color(red: 0.40, green: 0.47, blue: 0.58)

    // Поверхности
    static let appCard = Color(UIColor.systemBackground)
    static let appBackground = Color(UIColor.secondarySystemBackground)
    static let appBorder = Color(red: 0.88, green: 0.90, blue: 0.93)
}
