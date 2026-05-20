import Foundation

#if canImport(AppMetricaCore)
import AppMetricaCore
#endif

enum AppMetricaReporter {

    static func start() {
        #if canImport(AppMetricaCore)
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "APPMETRICA_API_KEY") as? String,
              !apiKey.isEmpty,
              apiKey != "$(APPMETRICA_API_KEY)" else {
            Log.debug("AppMetrica: API key not set, analytics disabled")
            return
        }
        guard let configuration = AppMetricaConfiguration(apiKey: apiKey) else {
            Log.debug("AppMetrica: invalid API key format")
            return
        }
        let bundle = Bundle.main
        configuration.appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        configuration.appBuildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        configuration.appOpenTrackingEnabled = false
        #if DEBUG
        configuration.areLogsEnabled = true
        #endif
        AppMetrica.activate(with: configuration)
        reportAppStart()
        #endif
    }

    static func setGuestUUID(_ uuid: String?) {
        // Не прокидываем guest UUID как profile id: в AppMetrica SDK 6.x это
        // может поднять отдельный reporter в логах с UUID вместо основного apiKey.
        // События должны уходить только в проект APPMETRICA_API_KEY.
        _ = uuid
    }

    static func screen(_ name: String, data: [String: Any] = [:]) {
        event("screen_\(name)", data: data)
    }

    static func action(_ name: String, data: [String: Any] = [:]) {
        event(name, data: data)
    }

    static func trackOpenURL(_ url: URL) {
        #if canImport(AppMetricaCore)
        AppMetrica.trackOpeningURL(url)
        #endif
    }

    private static func event(_ name: String, data: [String: Any]) {
        #if canImport(AppMetricaCore)
        let params = normalized(data)
        AppMetrica.reportEvent(name: name, parameters: params.isEmpty ? nil : params, onFailure: nil)
        #endif
    }

    private static func reportAppStart() {
        let bundle = Bundle.main
        event("app_start", data: [
            "bundle_id": bundle.bundleIdentifier ?? "",
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        ])
    }

    private static func normalized(_ data: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in data {
            switch value {
            case let s as String:
                out[key] = s
            case let b as Bool:
                out[key] = b
            case let n as NSNumber:
                out[key] = n
            case let d as Double:
                out[key] = d
            case let i as Int:
                out[key] = i
            default:
                out[key] = String(describing: value)
            }
        }
        return out
    }
}
