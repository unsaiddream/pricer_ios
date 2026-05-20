import XCTest
import UIKit
import UserNotifications
@testable import MinPrice

final class MinPriceTests: XCTestCase {
    func testGuestUUIDPersists() {
        let api = APIClient.shared
        let first = api.guestUUID
        let second = api.guestUUID
        XCTAssertEqual(first, second)
    }

    func testBadgeUpdateDoesNotRequestPermissionWhenStatusIsNotDetermined() {
        XCTAssertFalse(CartStore.canUpdateBadge(for: .notDetermined))
    }

    func testBadgeUpdateAllowedOnlyAfterNotificationAuthorization() {
        XCTAssertTrue(CartStore.canUpdateBadge(for: .authorized))
        XCTAssertTrue(CartStore.canUpdateBadge(for: .provisional))
        XCTAssertTrue(CartStore.canUpdateBadge(for: .ephemeral))

        XCTAssertFalse(CartStore.canUpdateBadge(for: .denied))
    }

    func testProductShareItemsIncludeSeparateProductURL() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        let url = try XCTUnwrap(URL(string: "https://minprice.kz/products/test-product/"))
        let item = ShareImageItem(image: image, url: url, productTitle: "Молоко")

        let sharedURL = try XCTUnwrap(item.activityItems.compactMap { $0 as? URL }.first)
        let sharedText = try XCTUnwrap(item.activityItems.compactMap { $0 as? String }.first)

        XCTAssertEqual(sharedURL, url)
        XCTAssertTrue(sharedText.contains("Молоко"))
        XCTAssertTrue(sharedText.contains(url.absoluteString))
    }

    func testCartSummarySnapshotUsesTotalQuantitiesAndCheapestTotal() throws {
        let json = """
        {
          "cart": {
            "uuid": "cart-1",
            "name": "Active",
            "isActive": true,
            "items": [],
            "itemsCount": 1,
            "createdAt": "2026-05-18T00:00:00Z",
            "updatedAt": "2026-05-18T00:00:01Z"
          },
          "totalItems": 3,
          "cheapestPerProduct": [
            {
              "product": {
                "id": 1,
                "uuid": "product-1",
                "title": "Помидоры",
                "brand": null,
                "imageUrl": null,
                "measureUnit": null,
                "measureUnitKind": null,
                "measureUnitQty": null,
                "packCount": null,
                "minPrice": 100,
                "maxPrice": 150,
                "isActive": true,
                "linkedStoresCount": 1,
                "stores": [],
                "description": null,
                "priceRange": null
              },
              "quantity": 3,
              "storeId": 10,
              "storeName": "Store",
              "chainName": "Store",
              "chainSlug": "store",
              "chainLogo": null,
              "chainSource": "store",
              "price": 100,
              "itemTotal": 300,
              "currency": "KZT",
              "url": null,
              "extProductId": null,
              "extProductTitle": null,
              "extProductImage": null
            }
          ],
          "cheapestTotalPrice": 300,
          "groupedByStore": [],
          "unavailableProducts": [],
          "singleStoreTotals": []
        }
        """
        let summary = try JSONDecoder().decode(CartSummaryResponse.self, from: Data(json.utf8))

        XCTAssertEqual(summary.cartStateSnapshot.itemsCount, 3)
        XCTAssertEqual(summary.cartStateSnapshot.total, 300)
    }

    func testCartSummarySnapshotAppliesQuantityOverrides() throws {
        let json = """
        {
          "cart": {
            "uuid": "cart-1",
            "name": "Active",
            "isActive": true,
            "items": [
              {
                "id": 1,
                "product": {
                  "id": 1,
                  "uuid": "product-1",
                  "title": "Помидоры",
                  "brand": null,
                  "imageUrl": null,
                  "measureUnit": null,
                  "measureUnitKind": null,
                  "measureUnitQty": null,
                  "packCount": null,
                  "minPrice": 100,
                  "maxPrice": 150,
                  "isActive": true,
                  "linkedStoresCount": 1,
                  "stores": [],
                  "description": null,
                  "priceRange": null
                },
                "quantity": 1,
                "addedAt": "2026-05-18T00:00:00Z",
                "updatedAt": "2026-05-18T00:00:01Z"
              }
            ],
            "itemsCount": 1,
            "createdAt": "2026-05-18T00:00:00Z",
            "updatedAt": "2026-05-18T00:00:01Z"
          },
          "totalItems": 1,
          "cheapestPerProduct": [
            {
              "product": {
                "id": 1,
                "uuid": "product-1",
                "title": "Помидоры",
                "brand": null,
                "imageUrl": null,
                "measureUnit": null,
                "measureUnitKind": null,
                "measureUnitQty": null,
                "packCount": null,
                "minPrice": 100,
                "maxPrice": 150,
                "isActive": true,
                "linkedStoresCount": 1,
                "stores": [],
                "description": null,
                "priceRange": null
              },
              "quantity": 1,
              "storeId": 10,
              "storeName": "Store",
              "chainName": "Store",
              "chainSlug": "store",
              "chainLogo": null,
              "chainSource": "store",
              "price": 100,
              "itemTotal": 100,
              "currency": "KZT",
              "url": null,
              "extProductId": null,
              "extProductTitle": null,
              "extProductImage": null
            }
          ],
          "cheapestTotalPrice": 100,
          "groupedByStore": [],
          "unavailableProducts": [],
          "singleStoreTotals": []
        }
        """
        let summary = try JSONDecoder().decode(CartSummaryResponse.self, from: Data(json.utf8))
        let snapshot = summary.cartStateSnapshot(quantityOverrides: ["product-1": 4])

        XCTAssertEqual(snapshot.itemsCount, 4)
        XCTAssertEqual(snapshot.total, 400)
        XCTAssertEqual(snapshot.cart.itemsCount, 4)
        XCTAssertEqual(snapshot.cart.items.first?.quantity, 4)
    }

    func testCartSummaryWithOnlyUnavailableProductsIsStillVisible() throws {
        let json = """
        {
          "cart": {
            "uuid": "cart-1",
            "name": "Active",
            "isActive": true,
            "items": [],
            "itemsCount": 1,
            "createdAt": "2026-05-18T00:00:00Z",
            "updatedAt": "2026-05-18T00:00:01Z"
          },
          "totalItems": 1,
          "cheapestPerProduct": [],
          "cheapestTotalPrice": 0,
          "groupedByStore": [],
          "unavailableProducts": [
            {
              "product": {
                "id": 1,
                "uuid": "product-1",
                "title": "Помидоры",
                "brand": null,
                "imageUrl": null,
                "measureUnit": null,
                "measureUnitKind": null,
                "measureUnitQty": null,
                "packCount": null,
                "minPrice": 100,
                "maxPrice": 150,
                "isActive": true,
                "linkedStoresCount": 1,
                "stores": [],
                "description": null,
                "priceRange": null
              },
              "quantity": 1,
              "reason": "Нет в наличии"
            }
          ],
          "singleStoreTotals": []
        }
        """
        let summary = try JSONDecoder().decode(CartSummaryResponse.self, from: Data(json.utf8))

        XCTAssertTrue(summary.hasVisibleItems)
    }
}
