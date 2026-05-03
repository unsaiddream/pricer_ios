import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }()

    var body: some View {
        NavigationStack {
            List {
                // Логотип + версия
                Section {
                    VStack(spacing: 12) {
                        Image("AppIcon-1024")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)

                        Text("minprice.kz")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appPrimary)

                        Text("Версия \(appVersion)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.appMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.appCard)

                // Правовые документы
                Section("Документы") {
                    LinkRow(
                        icon: "hand.raised",
                        title: "Политика конфиденциальности",
                        url: "https://minprice.kz/privacy/"
                    )
                    LinkRow(
                        icon: "doc.plaintext",
                        title: "Публичная оферта",
                        url: "https://minprice.kz/public-offer/"
                    )
                }
                .listRowBackground(Color.appCard)

                // Поддержка
                Section("Поддержка") {
                    LinkRow(
                        icon: "envelope",
                        title: "Написать нам",
                        url: "mailto:support@minprice.kz"
                    )
                    LinkRow(
                        icon: "globe",
                        title: "minprice.kz",
                        url: "https://minprice.kz"
                    )
                }
                .listRowBackground(Color.appCard)

                // О приложении
                Section("О приложении") {
                    InfoRow(label: "Разработчик", value: "minprice.kz")
                    InfoRow(label: "Версия", value: appVersion)
                    InfoRow(label: "Платформа", value: "iOS 16.0+")
                }
                .listRowBackground(Color.appCard)

                Section {
                    Text("minprice.kz помогает найти самые выгодные цены в супермаркетах вашего города. Мы не являемся продавцом товаров — вся информация о ценах поступает от партнёрских магазинов.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.appCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("О приложении")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let url: String

    var body: some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.appPrimary)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appForeground)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.appMuted)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.appForeground)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Color.appMuted)
        }
    }
}
