import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Product] = []
    @Published var isLoading = false
    @Published var page = 0
    @Published var hasMore = false

    private let api = APIClient.shared
    private var searchTask: Task<Void, Never>?

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
        } catch {
            // Ошибка поиска — не показываем алерт, просто оставляем прежние результаты
        }

        isLoading = false
    }
}
