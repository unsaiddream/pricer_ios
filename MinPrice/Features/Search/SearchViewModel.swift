import Foundation
import Combine

enum SearchSort: String, CaseIterable, Identifiable {
    case relevance = "Релевантность"
    case priceLow  = "Дешевле"
    case priceHigh = "Дороже"
    case discount  = "Скидка"
    var id: String { rawValue }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Product] = []
    @Published var isLoading = false
    @Published var page = 0
    @Published var hasMore = false
    @Published var totalHits = 0
    @Published var recentSearches: [String] = []
    @Published var sort: SearchSort = .relevance

    var sortedResults: [Product] {
        switch sort {
        case .relevance: return results
        case .priceLow:  return results.sorted { ($0.cheapestPrice ?? .infinity) < ($1.cheapestPrice ?? .infinity) }
        case .priceHigh: return results.sorted { ($0.cheapestPrice ?? 0) > ($1.cheapestPrice ?? 0) }
        case .discount:
            return results.sorted { lhs, rhs in
                let l = lhs.meanMinDiscountPercent
                let r = rhs.meanMinDiscountPercent
                if l == r {
                    return (lhs.cheapestPrice ?? .infinity) < (rhs.cheapestPrice ?? .infinity)
                }
                return l > r
            }
        }
    }

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?
    private var searchSessionId = UUID()
    private let recentKey = "recent_searches_v1"
    private let maxRecent = 8

    init() { loadRecent() }

    func searchImmediate(cityId: Int) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searchTask?.cancel()
        searchSessionId = UUID()
        await performSearch(cityId: cityId, page: 0, append: false)
    }

    func search(cityId: Int) async {
        guard query.count >= 2 else {
            results = []
            totalHits = 0
            return
        }

        searchTask?.cancel()
        searchSessionId = UUID()
        page = 0

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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

    func removeRecent(_ q: String) {
        recentSearches.removeAll { $0 == q }
        UserDefaults.standard.set(recentSearches, forKey: recentKey)
    }

    private func performSearch(cityId: Int, page: Int, append: Bool) async {
        let requestQuery = query
        let requestSession = searchSessionId
        isLoading = true

        let items = [
            URLQueryItem(name: "q", value: requestQuery),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "hitsPerPage", value: "20"),
        ]

        do {
            let response = try await api.fetch(SearchResponse.self, path: Endpoint.search(), queryItems: items)
            guard requestSession == searchSessionId, requestQuery == query else { return }
            if append {
                // Дедуп — иначе ForEach падает с дублями UUID на скролле.
                let existing = Set(results.map(\.uuid))
                let fresh = response.hits.filter { !existing.contains($0.uuid) }
                results = results + fresh
            } else {
                results = response.hits
                totalHits = response.nbHits
            }
            self.page = response.page
            hasMore = response.page + 1 < response.nbPages
            if !append && !requestQuery.isEmpty { saveToRecent(requestQuery) }
        } catch {}

        if requestSession == searchSessionId {
            isLoading = false
        }
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
