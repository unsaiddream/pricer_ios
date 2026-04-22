import XCTest
@testable import MinPrice

final class MinPriceTests: XCTestCase {
    func testGuestUUIDPersists() {
        let api = APIClient.shared
        let first = api.guestUUID
        let second = api.guestUUID
        XCTAssertEqual(first, second)
    }
}
