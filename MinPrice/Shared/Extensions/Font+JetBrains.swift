import SwiftUI

extension Font {
    static func jb(_ size: CGFloat, weight: JBWeight = .medium) -> Font {
        .system(size: size, weight: weight.swiftUIWeight, design: .rounded)
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
