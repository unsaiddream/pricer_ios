import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var bestDeals: [Product] = []
    @Published var priceDrops: [Product] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func load(cityId: Int) async {
        isLoading = true
        errorMessage = nil
        let cityParam = URLQueryItem(name: "city_id", value: String(cityId))

        if categories.isEmpty {
            if let r = try? await api.fetch(CategoriesResponse.self, path: Endpoint.categories()) {
                categories = r.categories
            }
        }

        // Грузим независимо — частичный провал не блокирует другое
        async let dealsResult: Result<BestDealsResponse, Error> = {
            do { return .success(try await api.fetch(BestDealsResponse.self, path: Endpoint.bestDeals(), queryItems: [cityParam])) }
            catch { return .failure(error) }
        }()

        async let dropsResult: Result<PriceDropsResponse, Error> = {
            do { return .success(try await api.fetch(PriceDropsResponse.self, path: Endpoint.priceDrops(), queryItems: [cityParam])) }
            catch { return .failure(error) }
        }()

        let (deals, drops) = await (dealsResult, dropsResult)

        switch deals {
        case .success(let r): bestDeals = r.deals
        case .failure(let e): errorMessage = e.localizedDescription
        }

        switch drops {
        case .success(let r): priceDrops = r.results
        case .failure(let e): if errorMessage == nil { errorMessage = e.localizedDescription }
        }

        isLoading = false
    }
}
