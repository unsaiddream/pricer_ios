import WidgetKit
import SwiftUI

@main
struct MinPriceWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PriceDropWidget()
        FavoritesWidget()
        CartWidget()
    }
}
