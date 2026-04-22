import SwiftUI
import Kingfisher

// Логотип магазина: сначала пробуем URL из API, fallback — локальный ассет
struct StoreLogoView: View {
    let url: URL?
    let source: String?
    var size: CGFloat = 24

    private var localAsset: String? {
        switch source {
        case "mgo":        return "store_magnum"
        case "arbuz":      return "store_arbuz"
        case "airbafresh": return "store_airba_fresh"
        case "wolt":       return "store_small"
        case "instashop":  return nil
        default:           return nil
        }
    }

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .placeholder { localFallback }
                    .resizable()
                    .scaledToFit()
            } else {
                localFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }

    @ViewBuilder
    private var localFallback: some View {
        if let asset = localAsset, UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color.appBorder)
                .overlay(
                    Text(source?.prefix(1).uppercased() ?? "?")
                        .font(.system(size: size * 0.45, weight: .bold))
                        .foregroundStyle(Color.appMuted)
                )
        }
    }
}
