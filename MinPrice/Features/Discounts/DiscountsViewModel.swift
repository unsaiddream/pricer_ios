import Foundation

@MainActor
final class DiscountsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false

    private var page = 1
    private var hasMore = false
    private let api = APIClient.shared

    func load(cityId: Int, append: Bool = false) async {
        if append && isLoading { return }
        isLoading = true

        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]

        do {
            let r = try await api.fetch(DiscountsResponse.self, path: Endpoint.discounts(), queryItems: items)
            products = append ? products + r.results : r.results
            hasMore = page < r.totalPages
            if hasMore { page += 1 }
        } catch {}

        isLoading = false
    }

    func refresh(cityId: Int) async {
        page = 1
        hasMore = false
        products = []
        await load(cityId: cityId, append: false)
    }
}
