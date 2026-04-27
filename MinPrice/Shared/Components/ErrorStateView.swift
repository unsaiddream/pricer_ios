import SwiftUI

/// Централизованный empty/error state для экранов с сетевыми загрузками.
/// Заменяет "пустой скелетон навсегда" / "пустой экран без объяснений".
///
/// Использование:
///   ErrorStateView(.networkError, retry: { Task { await vm.load(...) } })
///   ErrorStateView(.empty(message: "Нет товаров"))
struct ErrorStateView: View {
    enum Kind {
        case networkError
        case serverError
        case empty(title: String, message: String, systemImage: String = "tray")
        case custom(title: String, message: String, systemImage: String, accent: Color)
    }

    let kind: Kind
    var retry: (() -> Void)?

    init(_ kind: Kind, retry: (() -> Void)? = nil) {
        self.kind = kind
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            if let retry {
                Button(action: retry) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("Повторить")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(LinearGradient.brandPrimary, in: Capsule())
                    .shadow(color: Color.appPrimary.opacity(0.30), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Per-kind copy

    private var title: String {
        switch kind {
        case .networkError:        return "Нет соединения"
        case .serverError:         return "Что-то пошло не так"
        case .empty(let t, _, _):  return t
        case .custom(let t, _, _, _): return t
        }
    }

    private var message: String {
        switch kind {
        case .networkError:        return "Проверьте подключение и попробуйте снова"
        case .serverError:         return "Сервер сейчас не отвечает. Попробуйте чуть позже."
        case .empty(_, let m, _):  return m
        case .custom(_, let m, _, _): return m
        }
    }

    private var systemImage: String {
        switch kind {
        case .networkError:           return "wifi.exclamationmark"
        case .serverError:            return "exclamationmark.triangle"
        case .empty(_, _, let icon):  return icon
        case .custom(_, _, let icon, _): return icon
        }
    }

    private var accent: Color {
        switch kind {
        case .networkError:        return .discountRed
        case .serverError:         return .warningAmber
        case .empty:               return .appPrimary
        case .custom(_, _, _, let c): return c
        }
    }
}
