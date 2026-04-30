import Foundation
import Network
import SwiftUI

/// Глобальный observable-индикатор сетевого подключения.
///
/// Использование в SwiftUI:
///   @StateObject private var net = NetworkMonitor.shared
///   if !net.isConnected { OfflineBanner() }
///
/// `NWPathMonitor` уведомляет о смене статуса асинхронно через свой queue —
/// в @Published пишем уже на main, чтобы SwiftUI спокойно реагировал.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isExpensive: Bool = false      // мобильный/тариф
    @Published private(set) var isConstrained: Bool = false    // Low Data Mode

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "kz.minprice.net-monitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Пишем в @Published только на main, иначе SwiftUI ругается.
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isConnected != connected { self.isConnected = connected }
                if self.isExpensive != expensive { self.isExpensive = expensive }
                if self.isConstrained != constrained { self.isConstrained = constrained }
            }
        }
        monitor.start(queue: queue)
    }
}
