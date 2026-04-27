import XCTest
import SwiftUI
@testable import MinPrice

/// Бэкенд присылает цвета сетей в формате `#RRGGBB` через AppConfig.chainColors.
/// Если парсер сломается — все 6 сетей получат дефолтный цвет, и график станет
/// нечитаемым. Покрываю несколько форматов + обработку мусора.
final class HexColorTests: XCTestCase {

    func test_parses_standard_hex() {
        XCTAssertNotNil(Color(hex: "#FF6BA7"))
        XCTAssertNotNil(Color(hex: "FF6BA7"))            // без решётки
        XCTAssertNotNil(Color(hex: "  #FF6BA7  "))       // с пробелами
    }

    func test_parses_8_digit_hex_with_alpha() {
        XCTAssertNotNil(Color(hex: "#FF6BA780"))
        XCTAssertNotNil(Color(hex: "FF6BA780"))
    }

    func test_returns_nil_for_invalid() {
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: "abc"))               // длина не 6/8
        XCTAssertNil(Color(hex: "#XYZ123"))           // не hex символы
        XCTAssertNil(Color(hex: "#1234567"))          // длина 7 — невалидно
    }
}
