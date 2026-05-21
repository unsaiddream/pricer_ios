import SwiftUI

/// Хранит выбранные магазины-избранные. Влияет на все основные запросы:
/// если пользователь выбрал хотя бы один магазин — ко всем product-запросам
/// добавляется `chain_ids=...`, и бэкенд возвращает только товары из этих сетей.
///
/// Хранение — UserDefaults (через @AppStorage с CSV строкой), потому что
/// у SwiftUI нет встроенной поддержки Set<Int> в @AppStorage.
@MainActor
final class FavoriteStoresStore: ObservableObject {
    static let shared = FavoriteStoresStore()

    @Published private(set) var chains: [Chain] = []
    @Published private(set) var selectedIds: Set<Int> = []

    /// CSV — "10,17,3" — потому что @AppStorage не поддерживает Set/Array без обёртки
    @AppStorage("minprice_favorite_chains_csv") private var csv: String = ""

    private init() {
        // Восстанавливаем из @AppStorage при инициализации
        rehydrate()
    }

    private func rehydrate() {
        let parsed = csv
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        selectedIds = Set(parsed)
    }

    private func persist() {
        csv = selectedIds.sorted().map(String.init).joined(separator: ",")
    }

    /// Загружаем список доступных сетей с бэкенда.
    /// Без сети — пустой массив; UI покажет skeleton.
    func loadChains() async {
        guard chains.isEmpty else { return }
        do {
            let response = try await APIClient.shared.fetch(ChainsResponse.self, path: Endpoint.chains())
            chains = response.chains
            // Очищаем selectedIds от устаревших ID (например, если сеть была удалена)
            let validIds = Set(response.chains.map(\.id))
            let cleaned = selectedIds.intersection(validIds)
            if cleaned != selectedIds {
                selectedIds = cleaned
                persist()
            }
        } catch {
            Log.debug("⚠️ chains load failed: \(error)")
        }
    }

    func toggle(_ chainId: Int) {
        if selectedIds.contains(chainId) {
            selectedIds.remove(chainId)
        } else {
            selectedIds.insert(chainId)
        }
        persist()
        HapticManager.selection()
    }

    func clear() {
        selectedIds.removeAll()
        persist()
    }

    /// CSV для отправки на бэкенд. nil если магазины не выбраны.
    var chainIdsCSV: String? {
        guard !selectedIds.isEmpty else { return nil }
        return selectedIds.sorted().map(String.init).joined(separator: ",")
    }

    /// Готовый URLQueryItem (или nil, если ничего не выбрано).
    var queryItem: URLQueryItem? {
        guard let csv = chainIdsCSV else { return nil }
        return URLQueryItem(name: "chain_ids", value: csv)
    }
}
