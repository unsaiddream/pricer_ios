import SwiftUI

/// AboutView в drinkit-вайбе: огромный display-шрифт, крошечные UPPERCASE-eyebrow,
/// много воздуха, чистые карточки без теней. Минимум декора, максимум типографики.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    hero
                    featuresSection
                    storesSection
                    documentsSection
                    supportSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Color.appForeground)
                            .frame(width: 34, height: 34)
                            .background(Color.appCard, in: Circle())
                            .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.6))
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("minprice")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .kerning(-1.8)
                        .foregroundStyle(Color.appForeground)
                    Text(".kz")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .kerning(-1.8)
                        .foregroundStyle(Color.appPrimary)
                }
                Text("Минимальные цены.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appMuted)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Sections

    private var featuresSection: some View {
        Section(eyebrow: "Что умеет") {
            VStack(spacing: 10) {
                FeatureCard(icon: "tag.fill",
                            title: "Сравнение цен",
                            subtitle: "6 магазинов одним тапом",
                            tint: Color.savingsGreen)
                FeatureCard(icon: "cart.fill",
                            title: "Умная корзина",
                            subtitle: "Считает экономию vs покупка в одном магазине",
                            tint: Color.appPrimary)
                FeatureCard(icon: "barcode.viewfinder",
                            title: "Сканер штрих-кодов",
                            subtitle: "Камера → товар в каталоге",
                            tint: .orange)
                FeatureCard(icon: "bell.fill",
                            title: "Алерты на снижение",
                            subtitle: "Уведомим, когда товар подешевеет",
                            tint: .pink)
            }
        }
    }

    private var storesSection: some View {
        Section(eyebrow: "Партнёры") {
            HStack(spacing: 12) {
                ForEach(["store_magnum", "store_arbuz", "store_airba_fresh", "store_small"], id: \.self) { asset in
                    ZStack {
                        Color.white
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.appBorder, lineWidth: 0.6)
                    )
                }
            }
        }
    }

    private var documentsSection: some View {
        Section(eyebrow: "Документы") {
            VStack(spacing: 0) {
                LinkRow(title: "Политика конфиденциальности",
                        url: "https://minprice.kz/privacy/")
                Divider().overlay(Color.appBorder)
                LinkRow(title: "Публичная оферта",
                        url: "https://minprice.kz/public-offer/")
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 0.6)
            )
        }
    }

    private var supportSection: some View {
        Section(eyebrow: "Поддержка") {
            VStack(spacing: 0) {
                LinkRow(title: "Написать нам",
                        subtitle: "support@minprice.kz",
                        url: "mailto:support@minprice.kz")
                Divider().overlay(Color.appBorder)
                LinkRow(title: "minprice.kz",
                        subtitle: "Сайт в браузере",
                        url: "https://minprice.kz")
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 0.6)
            )
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Color.appBorder)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Версия".uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .kerning(1.4)
                        .foregroundStyle(Color.appMuted)
                    Text(appVersion)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.appForeground)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Сделано в".uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .kerning(1.4)
                        .foregroundStyle(Color.appMuted)
                    Text("Казахстане 🇰🇿")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.appForeground)
                }
            }
            .padding(.top, 4)

            Text("Цены отображаются по данным партнёрских магазинов и могут отличаться от итоговых на кассе.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.appMuted.opacity(0.7))
                .padding(.top, 12)
        }
    }
}

// MARK: - Section wrapper

private struct Section<Content: View>: View {
    let eyebrow: String
    let content: () -> Content

    init(eyebrow: String, @ViewBuilder content: @escaping () -> Content) {
        self.eyebrow = eyebrow
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .kerning(1.6)
                .foregroundStyle(Color.appPrimary)
            content()
        }
    }
}

// MARK: - Feature card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .kerning(-0.2)
                    .foregroundStyle(Color.appForeground)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 0.6)
        )
    }
}

// MARK: - Link row

private struct LinkRow: View {
    let title: String
    var subtitle: String? = nil
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.appForeground)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Color.appMuted)
                    }
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.appMuted.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
