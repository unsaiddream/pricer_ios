import XCTest
@testable import MinPrice

/// Тесты на VersionGate в AppConfig — он решает, какой экран показать
/// (force-update / soft-update / maintenance / ok). Если эта логика
/// сломается, пользователи могут залипнуть на ForceUpdateView навсегда
/// или наоборот не получить блокировку при критическом баге.
final class AppConfigTests: XCTestCase {

    private func makeConfig(
        min: String? = nil,
        rec: String? = nil,
        maintenance: AppConfig.Maintenance? = nil
    ) -> AppConfig {
        AppConfig(
            minSupportedVersion: min,
            recommendedVersion: rec,
            appStoreUrl: "https://apps.apple.com/...",
            maintenance: maintenance,
            chainColors: nil,
            popularBrands: nil,
            homeBanners: nil,
            features: nil,
            copy: nil,
            configVersion: 1
        )
    }

    // MARK: - VersionGate

    func test_versionGate_returnsOk_whenNoVersionConstraints() {
        let cfg = makeConfig()
        if case .ok = cfg.versionGate(currentVersion: "1.0.0") { /* ok */ }
        else { XCTFail("expected .ok") }
    }

    func test_versionGate_forceUpdate_whenCurrentBelowMin() {
        let cfg = makeConfig(min: "1.2.0")
        if case .forceUpdate = cfg.versionGate(currentVersion: "1.1.0") { /* ok */ }
        else { XCTFail("expected .forceUpdate") }
    }

    func test_versionGate_softUpdate_whenCurrentBelowRecommended() {
        let cfg = makeConfig(min: "1.0.0", rec: "1.2.0")
        if case .softUpdate = cfg.versionGate(currentVersion: "1.1.0") { /* ok */ }
        else { XCTFail("expected .softUpdate") }
    }

    func test_versionGate_ok_whenCurrentEqualsRecommended() {
        let cfg = makeConfig(min: "1.0.0", rec: "1.2.0")
        if case .ok = cfg.versionGate(currentVersion: "1.2.0") { /* ok */ }
        else { XCTFail("expected .ok at exact match") }
    }

    func test_versionGate_maintenance_takesPriorityOverVersion() {
        let m = AppConfig.Maintenance(enabled: true, message: "обновляем", endsAt: nil)
        // Даже при breaking-version maintenance должен побеждать —
        // юзер сначала увидит maintenance-экран
        let cfg = makeConfig(min: "99.0.0", rec: "99.0.0", maintenance: m)
        if case .maintenance(let msg) = cfg.versionGate(currentVersion: "1.0.0") {
            XCTAssertEqual(msg, "обновляем")
        } else {
            XCTFail("expected .maintenance")
        }
    }

    func test_versionGate_handlesDoubleDigitVersions() {
        // 1.10.0 > 1.9.5 — лексикографическое сравнение строк сломалось бы здесь
        let cfg = makeConfig(min: "1.10.0")
        if case .ok = cfg.versionGate(currentVersion: "1.10.5") { /* ok */ }
        else { XCTFail("1.10.5 should be >= 1.10.0") }

        if case .forceUpdate = cfg.versionGate(currentVersion: "1.9.99") { /* ok */ }
        else { XCTFail("1.9.99 < 1.10.0 — должен быть forceUpdate") }
    }

    func test_versionGate_handlesShortVersions() {
        // "1.0" против "1.0.5" — недостающие компоненты считаются нулём
        let cfg = makeConfig(min: "1.0.0")
        if case .ok = cfg.versionGate(currentVersion: "1.0") { /* ok */ }
        else { XCTFail("1.0 == 1.0.0") }
    }

    // MARK: - Feature flags

    func test_isEnabled_defaultsToTrue_whenNoConfig() {
        let cfg = AppConfig.fallback
        XCTAssertTrue(cfg.isEnabled(.storeBasketChart))
        XCTAssertTrue(cfg.isEnabled(.discountsTab))
    }

    func test_isEnabled_respectsExplicitFalse() {
        let cfg = AppConfig(
            minSupportedVersion: nil, recommendedVersion: nil, appStoreUrl: nil,
            maintenance: nil, chainColors: nil, popularBrands: nil, homeBanners: nil,
            features: ["store_basket_chart": false],
            copy: nil, configVersion: 1
        )
        XCTAssertFalse(cfg.isEnabled(.storeBasketChart))
        // Остальные не упомянутые — дефолт true
        XCTAssertTrue(cfg.isEnabled(.discountsTab))
    }
}
