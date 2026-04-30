import SwiftUI

/// Главный гейт между сплэшем и приложением.
/// Логика:
/// 1) Сплэш до тех пор, пока RemoteConfigStore не отметит `isLoaded`.
///    Если сети нет — кэш или fallback отдаёт isLoaded=true сразу.
/// 2) Force-update: блокирующий экран со ссылкой в App Store.
/// 3) Maintenance: блокирующий экран с сообщением.
/// 4) Иначе — обычный ContentView. Soft-update показывается баннером поверх него.
struct LaunchGate: View {
    @StateObject private var configStore = RemoteConfigStore.shared
    @StateObject private var net = NetworkMonitor.shared
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var didStartFetch = false

    var body: some View {
        ZStack {
            switch configStore.versionGate {
            case .forceUpdate:
                ForceUpdateView(storeURL: configStore.config.appStoreUrl)
                    .transition(.opacity)
            case .maintenance(let message):
                MaintenanceView(message: message)
                    .transition(.opacity)
            case .softUpdate, .ok:
                if hasOnboarded {
                    ContentView()
                        .overlay(alignment: .top) {
                            VStack(spacing: 6) {
                                if !net.isConnected {
                                    OfflineBanner()
                                }
                                if case .softUpdate = configStore.versionGate {
                                    SoftUpdateBanner(storeURL: configStore.config.appStoreUrl)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .animation(.easeInOut(duration: 0.25), value: net.isConnected)
                        }
                        .transition(.opacity)
                } else {
                    OnboardingView(onComplete: { hasOnboarded = true })
                        .transition(.opacity)
                }
            }

            if !configStore.isLoaded {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: configStore.isLoaded)
        .animation(.easeInOut(duration: 0.25), value: hasOnboarded)
        .task {
            guard !didStartFetch else { return }
            didStartFetch = true
            await configStore.refresh()
        }
    }
}

// MARK: - Offline banner

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Нет соединения")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("Проверьте интернет")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.discountRed, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.discountRed.opacity(0.35), radius: 10, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Splash

private struct SplashView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                Text("minprice.kz")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.brandPrimary)
                ProgressView()
                    .tint(Color.appPrimary)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Force update

private struct ForceUpdateView: View {
    let storeURL: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.10))
                    .frame(width: 120, height: 120)
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(LinearGradient.brandPrimary)
            }

            VStack(spacing: 10) {
                Text("Доступно обновление")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appForeground)

                Text("Эта версия больше не поддерживается. Обновитесь, чтобы продолжить пользоваться minprice.kz.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                if let s = storeURL, let url = URL(string: s) { openURL(url) }
            } label: {
                Text("Обновить в App Store")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.brandPrimary, in: Capsule())
                    .shadow(color: Color.appPrimary.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .disabled(storeURL == nil)
            .opacity(storeURL == nil ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Maintenance

private struct MaintenanceView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.warningAmber.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(Color.warningAmber)
            }

            VStack(spacing: 10) {
                Text("Технические работы")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appForeground)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Soft update banner

private struct SoftUpdateBanner: View {
    let storeURL: String?
    @Environment(\.openURL) private var openURL
    @State private var dismissed = false

    var body: some View {
        if dismissed {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.appPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Новая версия доступна")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                    Text("Обновите для лучшего опыта")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
                Spacer()
                if let s = storeURL, let url = URL(string: s) {
                    Button {
                        openURL(url)
                    } label: {
                        Text("Обновить")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    withAnimation { dismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.appMuted)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }
}
