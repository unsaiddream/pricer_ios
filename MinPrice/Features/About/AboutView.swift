import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var heroAppeared = false

    private let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroSection
                    featuresSection
                    storesSection
                    legalSection
                    supportSection
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient.homeBackground(isDark: isDarkMode)
                    .ignoresSafeArea()
            )
            .navigationTitle("О приложении")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 30, height: 30)
                            .background(Color.appCard, in: Circle())
                            .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.5))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                heroAppeared = true
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Декоративные кольца
                Circle()
                    .stroke(LinearGradient.brandPrimary.opacity(0.18), lineWidth: 2)
                    .frame(width: 150, height: 150)
                    .scaleEffect(heroAppeared ? 1.0 : 0.6)
                    .opacity(heroAppeared ? 1 : 0)
                Circle()
                    .stroke(LinearGradient.brandPrimary.opacity(0.10), lineWidth: 2)
                    .frame(width: 200, height: 200)
                    .scaleEffect(heroAppeared ? 1.0 : 0.5)
                    .opacity(heroAppeared ? 1 : 0)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .padding(8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.appPrimary.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: Color.appPrimary.opacity(0.30), radius: 18, x: 0, y: 8)
                    .scaleEffect(heroAppeared ? 1.0 : 0.85)
            }
            .frame(height: 200)

            VStack(spacing: 6) {
                Text("minprice.kz")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient.brandPrimary)

                Text("Минимальные цены в супермаркетах Казахстана")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 8) {
                BadgeChip(icon: "checkmark.seal.fill", text: "v\(appVersion)", tint: Color.appPrimary)
                BadgeChip(icon: "iphone", text: "iOS 16+", tint: Color.appMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appPrimary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.appPrimary.opacity(0.08), radius: 14, x: 0, y: 6)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Что умеет", icon: "sparkles")
            VStack(spacing: 8) {
                FeatureRow(icon: "tag.fill",
                           title: "Сравнение цен",
                           subtitle: "Минимальная цена в шести магазинах",
                           tint: Color.savingsGreen)
                FeatureRow(icon: "cart.fill",
                           title: "Умная корзина",
                           subtitle: "Считает экономию vs покупка в одном магазине",
                           tint: Color.appPrimary)
                FeatureRow(icon: "barcode.viewfinder",
                           title: "Сканер штрих-кодов",
                           subtitle: "Камера → находит товар в каталоге",
                           tint: .orange)
                FeatureRow(icon: "bell.fill",
                           title: "Алерты на снижение",
                           subtitle: "Уведомим когда товар подешевеет",
                           tint: .pink)
            }
        }
    }

    // MARK: - Stores

    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Партнёрские магазины", icon: "storefront.fill")
            HStack(spacing: 10) {
                ForEach(["store_magnum", "store_arbuz", "store_airba_fresh", "store_small"], id: \.self) { asset in
                    ZStack {
                        Color.white
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.appBorder, lineWidth: 0.5))
                }
                Spacer()
            }
            .padding(14)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Документы", icon: "doc.text.fill")
            VStack(spacing: 0) {
                LinkRow(icon: "hand.raised.fill",
                        title: "Политика конфиденциальности",
                        url: "https://minprice.kz/privacy/")
                Divider().overlay(Color.appBorder).padding(.leading, 50)
                LinkRow(icon: "doc.plaintext.fill",
                        title: "Публичная оферта",
                        url: "https://minprice.kz/public-offer/")
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Поддержка", icon: "lifepreserver.fill")
            VStack(spacing: 0) {
                LinkRow(icon: "envelope.fill",
                        title: "Написать в поддержку",
                        subtitle: "support@minprice.kz",
                        url: "mailto:support@minprice.kz")
                Divider().overlay(Color.appBorder).padding(.leading, 50)
                LinkRow(icon: "globe",
                        title: "Сайт minprice.kz",
                        subtitle: "Сравнение цен в браузере",
                        url: "https://minprice.kz")
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
        }
    }

    // MARK: - Footnote

    private var footnote: some View {
        VStack(spacing: 6) {
            Text("Сделано с ❤️ в Казахстане")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appMuted)
            Text("Цены отображаются по данным партнёрских магазинов и могут отличаться от итоговых на кассе.")
                .font(.system(size: 11))
                .foregroundStyle(Color.appMuted.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.top, 6)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appPrimary)
            Text(text)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.appForeground)
                .kerning(0.2)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Components

private struct BadgeChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 0.6))
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 0.5))
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appPrimary)
                    .frame(width: 30, height: 30)
                    .background(Color.appPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appForeground)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appMuted)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.appMuted.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
