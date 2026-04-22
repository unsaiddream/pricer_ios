import SwiftUI

extension Font {
    static func jb(_ size: CGFloat, weight: JBWeight = .medium) -> Font {
        .custom(weight.rawValue, size: size)
    }

    enum JBWeight: String {
        case regular  = "JetBrainsMono-Regular"
        case medium   = "JetBrainsMono-Medium"
        case semibold = "JetBrainsMono-SemiBold"
        case bold     = "JetBrainsMono-Bold"
    }
}
