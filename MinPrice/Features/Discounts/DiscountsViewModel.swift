import Foundation

enum DiscountsMode: String, CaseIterable {
    case discounts = "Скидки"
    case priceDrops = "Снижение"
    case priceIncreases = "Рост цен"

    var icon: String {
        switch self {
        case .discounts:     return "tag.fill"
        case .priceDrops:    return "arrow.down.circle.fill"
        case .priceIncreases: return "arrow.up.circle.fill"
        }
    }
}

@MainActor
final class DiscountsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var mode: DiscountsMode = .discounts {
        didSet { if oldValue != mode { Task { await refresh(cityId: lastCityId) } } }
    }

    private var page = 1
    private var hasMore = false
    private var lastCityId = 1
    private let api = APIClient.shared

    func load(cityId: Int, append: Bool = false) async {
        guard !isLoading else { return }
        lastCityId = cityId
        isLoading = true

        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]

        do {
            switch mode {
            case .discounts:
                let r = try await api.fetch(DiscountsResponse.self, path: Endpoint.discounts(), queryItems: items)
                products = append ? products + r.results : r.results
                hasMore = page < r.totalPages
            case .priceDrops:
                let r = try await api.fetch(PriceDropsResponse.self, path: Endpoint.priceDrops(), queryItems: items)
                products = append ? products + r.results : r.results
                hasMore = page < r.totalPages
            case .priceIncreases:
                let r = try await api.fetch(PriceIncreasesResponse.self, path: Endpoint.priceIncreases(), queryItems: items)
                products = append ? products + r.results : r.results
                hasMore = page < r.totalPages
            }
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
