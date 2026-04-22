import SwiftUI

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [Product] = []

    private let key = "favorites_v1"

    init() { load() }

    func toggle(_ product: Product) {
        if isFavorited(product.uuid) {
            favorites.removeAll { $0.uuid == product.uuid }
        } else {
            favorites.insert(product, at: 0)
        }
        save()
    }

    func isFavorited(_ uuid: String) -> Bool {
        favorites.contains { $0.uuid == uuid }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let products = try? JSONDecoder().decode([Product].self, from: data) else { return }
        favorites = products
    }
}
