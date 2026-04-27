import SwiftUI

/// 2-экранный onboarding для первого запуска.
/// 1) Welcome — что делает приложение
/// 2) City pick — выбор города (из CityStore.cities)
///
/// После завершения родитель переключает `hasOnboarded` через @AppStorage,
/// и LaunchGate показывает основной ContentView.
struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject var cityStore: CityStore
    @State private var step: Step = .welcome
    @State private var pickedCityId: Int?

    enum Step { case welcome, city }

    var body: some View {
        ZStack {
            LinearGradient.homeBackground(isDark: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Прогресс
                HStack(spacing: 6) {
                    Capsule()
                        .fill(step == .welcome ? Color.appPrimary : Color.appPrimary.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(step == .city ? Color.appPrimary : Color.appPrimary.opacity(0.25))
                        .frame(height: 4)
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .city:    cityStep
                    }
                }

                Spacer(minLength: 0)

                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .shadow(color: Color.appPrimary.opacity(0.30), radius: 18, x: 0, y: 8)

            VStack(spacing: 10) {
                Text("Сравнивайте цены\nпо 6 магазинам")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient.brandPrimary)

                Text("MagnumGO · Arbuz · Airba Fresh\nSmall · Galmart · Toimart")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.appMuted)
            }

            VStack(alignment: .leading, spacing: 14) {
                BulletRow(icon: "bag.fill",        text: "Покажем где дешевле каждый товар")
                BulletRow(icon: "chart.line.uptrend.xyaxis", text: "Отслеживаем историю цен")
                BulletRow(icon: "bell.badge.fill", text: "Сообщим, когда цена упала")
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    // MARK: - City

    private var cityStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(LinearGradient.brandPrimary)

            VStack(spacing: 8) {
                Text("Выберите город")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                Text("Цены и наличие зависят от города")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(availableCities, id: \.id) { city in
                    Button {
                        pickedCityId = city.id
                    } label: {
                        HStack {
                            Text(city.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appForeground)
                            Spacer()
                            if pickedCityId == city.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appPrimary)
                                    .font(.system(size: 20))
                            } else {
                                Circle()
                                    .stroke(Color.appBorder, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(pickedCityId == city.id ? Color.appPrimary.opacity(0.06) : Color.appCard)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(pickedCityId == city.id ? Color.appPrimary.opacity(0.5) : Color.appBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    /// Если CityStore не успел загрузиться — даём захардкоженный список,
    /// чтобы первый запуск не зависал на пустом экране.
    private var availableCities: [City] {
        if !cityStore.cities.isEmpty { return cityStore.cities }
        return [
            City(id: 1, name: "Алматы",  slug: "almaty"),
            City(id: 2, name: "Астана",  slug: "astana"),
            City(id: 3, name: "Шымкент", slug: "shymkent"),
        ]
    }

    // MARK: - Кнопка снизу

    private var primaryButton: some View {
        Button {
            switch step {
            case .welcome:
                step = .city
                if pickedCityId == nil {
                    pickedCityId = cityStore.selectedCityId
                }
            case .city:
                if let id = pickedCityId {
                    cityStore.selectedCityId = id
                }
                onComplete()
            }
        } label: {
            HStack(spacing: 8) {
                Text(step == .welcome ? "Далее" : "Поехали")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient.brandPrimary, in: Capsule())
            .shadow(color: Color.appPrimary.opacity(0.35), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(step == .city && pickedCityId == nil)
        .opacity(step == .city && pickedCityId == nil ? 0.55 : 1)
    }
}

// MARK: - Bullet row

private struct BulletRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28, height: 28)
                .background(Color.appPrimary.opacity(0.12), in: Circle())
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.appForeground.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
