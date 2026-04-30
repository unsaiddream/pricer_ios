import Foundation

func formatPriceTg(_ value: Double) -> String {
    let intValue = Int(round(value))
    let useGrouping = abs(intValue) >= 10_000
    if useGrouping {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: NSNumber(value: intValue)) ?? String(intValue)
        return "\(formatted) тг"
    }
    return "\(intValue) тг"
}

func formatPriceTg(_ value: Int) -> String {
    formatPriceTg(Double(value))
}
