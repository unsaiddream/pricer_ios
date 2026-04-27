import SwiftUI
import Kingfisher

/// Логотип магазина. Идентификация по chain_slug, потому что Small/Galmart/Toimart
/// имеют общий store_source = "wolt".
struct StoreLogoView: View {
    let url: URL?
    /// Slug сети (galmart/toimart/small/mgo/arbuz/airbafresh).
    /// Приоритет над `source` — нужен чтобы различать Wolt-сети.
    var slug: String? = nil
    /// Старое поле — поддерживаем для обратной совместимости (если slug не передали,
    /// fallback по source). Wolt без slug мапится на Small.
    let source: String?
    var size: CGFloat = 24

    /// Эффективный slug для маппинга ассетов и подложки.
    private var effectiveSlug: String? {
        if let s = slug?.lowercased() { return s }
        switch source?.lowercased() {
        case "mgo":        return "mgo"
        case "arbuz":      return "arbuz"
        case "airbafresh": return "airbafresh"
        case "wolt":       return "small"   // legacy дефолт
        case "small":      return "small"
        default:           return nil
        }
    }

    private var localAsset: String? {
        switch effectiveSlug {
        case "mgo":        return "store_magnum"
        case "arbuz":      return "store_arbuz"
        case "airbafresh": return "store_airba_fresh"
        case "small":      return "store_small"
        // galmart/toimart — без локальных ассетов; рисуем chain_logo с бэка
        default:           return nil
        }
    }

    private var corner: CGFloat { size * 0.28 }

    /// Прозрачные лого — нужна белая подложка, иначе на тёмном фоне их не видно.
    private var needsWhiteBg: Bool {
        switch effectiveSlug {
        case "airbafresh", "small", "galmart", "toimart": return true
        default: return false
        }
    }

    var body: some View {
        ZStack {
            if needsWhiteBg {
                Color.white
            }
            if let asset = localAsset, UIImage(named: asset) != nil {
                if needsWhiteBg {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.06)
                } else {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                }
            } else if let url {
                // Galmart/Toimart и любые новые сети — лого приходит URL-ом с бэка.
                KFImage(url)
                    .placeholder { letterContent }
                    .downsampled(to: CGSize(width: size, height: size))
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
                    .padding(needsWhiteBg ? size * 0.06 : 0)
            } else {
                letterContent
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var letterContent: some View {
        ZStack {
            Color.appBorder
            Text((effectiveSlug ?? source)?.prefix(1).uppercased() ?? "?")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(Color.appMuted)
        }
    }
}
