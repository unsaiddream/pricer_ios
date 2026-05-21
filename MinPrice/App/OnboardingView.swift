import SwiftUI

/// Onboarding для первого запуска — 3 шага:
/// 1) Welcome — что делает приложение (hero-стиль)
/// 2) City — выбор города
/// 3) Alerts — алерты на снижение + порог в %
///
/// После завершения родитель переключает `hasOnboarded` через @AppStorage,
/// и LaunchGate показывает основной ContentView.
struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject var cityStore: CityStore
    @AppStorage("price_alerts_enabled") private var alertsEnabled = false
    @AppStorage("price_alert_threshold_pct") private var alertThreshold = 5

    @State private var step: Step = .welcome
    @State private var pickedCityId: Int?
    @State private var heroAppeared = false

    enum Step: Int, CaseIterable {
        case welcome = 0, city = 1, alerts = 2
    }

    var body: some View {
        ZStack {
            // Двухслойный фон: основной + цветовое пятно по краю
            Color.appBackground.ignoresSafeArea()
            decorBackground

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .city:    cityStep
                    case .alerts:  alertsStep
                    }
                }

                Spacer(minLength: 0)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.1)) {
                heroAppeared = true
            }
        }
    }

    // MARK: - Decorative background

    private var decorBackground: some View {
        ZStack {
            // Цветной радиальный градиент — меняется в зависимости от шага
            RadialGradient(
                colors: [stepAccent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 380
            )
            RadialGradient(
                colors: [Color.appPrimary.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: step)
    }

    private var stepAccent: Color {
        switch step {
        case .welcome: return Color.appPrimary
        case .city:    return Color.appPrimary
        case .alerts:  return Color.savingsGreen
        }
    }

    // MARK: - Progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(stepFillColor(s))
                    .frame(height: 4)
            }
        }
    }

    private func stepFillColor(_ s: Step) -> Color {
        if s.rawValue <= step.rawValue {
            return s == step ? stepAccent : stepAccent.opacity(0.4)
        }
        return Color.appBorder
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            ZStack {
                // Декоративные кольца
                Circle()
                    .stroke(Color.appPrimary.opacity(0.08), lineWidth: 2)
                    .frame(width: 240, height: 240)
                    .scaleEffect(heroAppeared ? 1.0 : 0.5)
                Circle()
                    .stroke(Color.appPrimary.opacity(0.14), lineWidth: 2)
                    .frame(width: 180, height: 180)
                    .scaleEffect(heroAppeared ? 1.0 : 0.5)

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.appPrimary.opacity(0.30), radius: 22, x: 0, y: 10)
                    .scaleEffect(heroAppeared ? 1.0 : 0.85)
            }
            .frame(height: 220)
            .opacity(heroAppeared ? 1 : 0)

            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("minprice")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .kerning(-1.5)
                        .foregroundStyle(Color.appForeground)
                    Text(".kz")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .kerning(-1.5)
                        .foregroundStyle(Color.appPrimary)
                }
                Text("Минимальные цены в супермаркетах\nКазахстана. Сравниваем 6 магазинов.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                FeatureBullet(icon: "tag.fill",
                              text: "Где дешевле — видим сразу",
                              tint: Color.savingsGreen)
                FeatureBullet(icon: "cart.fill",
                              text: "Корзина считает экономию",
                              tint: Color.appPrimary)
                FeatureBullet(icon: "bell.badge.fill",
                              text: "Уведомим, когда цена упадёт",
                              tint: .orange)
            }
            .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
        .transition(.opacity)
    }

    // MARK: - Step 2: City

    private var cityStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "location.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.appPrimary)
            }

            VStack(spacing: 8) {
                Text("Где вы живёте?")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .kerning(-0.5)
                    .foregroundStyle(Color.appForeground)
                Text("Цены и наличие зависят от города")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(availableCities, id: \.id) { city in
                    cityRow(city)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func cityRow(_ city: City) -> some View {
        let selected = pickedCityId == city.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                pickedCityId = city.id
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Color.appPrimary : Color.appMuted.opacity(0.5))
                Text(city.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appPrimary)
                        .font(.system(size: 22, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .stroke(Color.appBorder, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.appPrimary.opacity(0.08) : Color.appCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.appPrimary.opacity(0.50) : Color.appBorder, lineWidth: 1)
            )
            .shadow(color: selected ? Color.appPrimary.opacity(0.15) : .clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var availableCities: [City] {
        if !cityStore.cities.isEmpty { return cityStore.cities }
        return [
            City(id: 1, name: "Алматы",  slug: "almaty"),
            City(id: 2, name: "Астана",  slug: "astana"),
            City(id: 3, name: "Шымкент", slug: "shymkent"),
        ]
    }

    // MARK: - Step 3: Alerts

    private var alertsStep: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.savingsGreen.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: alertsEnabled ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Color.savingsGreen)
                    .scaleEffect(alertsEnabled ? 1.06 : 1.0)
                    .animation(.spring(response: 0.32, dampingFraction: 0.6), value: alertsEnabled)
            }

            VStack(spacing: 8) {
                Text("Уведомлять о скидках?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .kerning(-0.5)
                    .foregroundStyle(Color.appForeground)
                Text("Раз в день проверим избранное и пришлём push,\nесли цена упала сильнее выбранного порога")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Toggle включения с пилюлей
            Button {
                Task {
                    HapticManager.selection()
                    if !alertsEnabled {
                        let granted = await PriceAlertManager.shared.requestPermission()
                        if granted {
                            alertsEnabled = true
                            PriceAlertManager.shared.isEnabled = true
                        }
                    } else {
                        alertsEnabled = false
                        PriceAlertManager.shared.isEnabled = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: alertsEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .bold))
                    Text(alertsEnabled ? "Уведомления включены" : "Включить уведомления")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(alertsEnabled ? .white : Color.savingsGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    alertsEnabled ? Color.savingsGreen : Color.savingsGreen.opacity(0.10),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(Color.savingsGreen.opacity(alertsEnabled ? 0 : 0.40), lineWidth: 1))
                .shadow(color: alertsEnabled ? Color.savingsGreen.opacity(0.30) : .clear, radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            // Threshold picker (только если уведомления включены)
            if alertsEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Порог")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .kerning(0.5)
                            .foregroundStyle(Color.appMuted)
                        Spacer()
                        Text("−\(alertThreshold)%")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.savingsGreen)
                            .contentTransition(.numericText())
                    }

                    HStack(spacing: 6) {
                        ForEach(PriceAlertManager.availableThresholds, id: \.self) { opt in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    alertThreshold = opt
                                }
                                HapticManager.selection()
                            } label: {
                                Text("\(opt)%")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(alertThreshold == opt ? .white : Color.appForeground)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .background(
                                        alertThreshold == opt ? Color.savingsGreen : Color.appCard,
                                        in: RoundedRectangle(cornerRadius: 11)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11)
                                            .stroke(alertThreshold == opt ? Color.clear : Color.appBorder, lineWidth: 0.6)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Bottom bar (back + primary)

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button {
                    if let prev = Step(rawValue: step.rawValue - 1) {
                        step = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.appForeground)
                        .frame(width: 56, height: 56)
                        .background(Color.appCard, in: Circle())
                        .overlay(Circle().stroke(Color.appBorder, lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Button {
                advance()
            } label: {
                HStack(spacing: 8) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                    Image(systemName: step == .alerts ? "checkmark" : "arrow.right")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    step == .alerts ? Color.savingsGreen : Color.appPrimary,
                    in: Capsule()
                )
                .shadow(
                    color: (step == .alerts ? Color.savingsGreen : Color.appPrimary).opacity(0.35),
                    radius: 12, x: 0, y: 5
                )
            }
            .buttonStyle(.plain)
            .disabled(primaryButtonDisabled)
            .opacity(primaryButtonDisabled ? 0.55 : 1)
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Начать"
        case .city:    return "Дальше"
        case .alerts:  return "Готово"
        }
    }

    private var primaryButtonDisabled: Bool {
        step == .city && pickedCityId == nil
    }

    private func advance() {
        switch step {
        case .welcome:
            if pickedCityId == nil { pickedCityId = cityStore.selectedCityId }
            step = .city
        case .city:
            if let id = pickedCityId { cityStore.selectedCityId = id }
            step = .alerts
        case .alerts:
            onComplete()
        }
    }
}

// MARK: - Feature bullet

private struct FeatureBullet: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 38, height: 38)

            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appForeground.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
