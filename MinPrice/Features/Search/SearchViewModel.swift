import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Product] = []
    @Published var isLoading = false
    @Published var page = 0
    @Published var hasMore = false
    @Published var recentSearches: [String] = []

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?
    private let recentKey = "recent_searches_v1"
    private let maxRecent = 8

    init() { loadRecent() }

    func search(cityId: Int) async {
        guard query.count >= 2 else {
            results = []
            return
        }

        searchTask?.cancel()
        page = 0

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce 300ms
            guard !Task.isCancelled else { return }
            await performSearch(cityId: cityId, page: 0, append: false)
        }
    }

    func loadMore(cityId: Int) async {
        guard hasMore, !isLoading else { return }
        await performSearch(cityId: cityId, page: page + 1, append: true)
    }

    func clearRecent() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    private func performSearch(cityId: Int, page: Int, append: Bool) async {
        isLoading = true

        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "hitsPerPage", value: "20"),
        ]

        do {
            let response = try await api.fetch(SearchResponse.self, path: Endpoint.search(), queryItems: items)
            if append {
                results += response.hits
            } else {
                results = response.hits
            }
            self.page = response.page
            hasMore = response.page + 1 < response.nbPages
            if !append && !query.isEmpty { saveToRecent(query) }
        } catch {}

        isLoading = false
    }

    private func saveToRecent(_ q: String) {
        var recent = recentSearches.filter { $0.lowercased() != q.lowercased() }
        recent.insert(q, at: 0)
        recentSearches = Array(recent.prefix(maxRecent))
        UserDefaults.standard.set(recentSearches, forKey: recentKey)
    }

    private func loadRecent() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }
}
