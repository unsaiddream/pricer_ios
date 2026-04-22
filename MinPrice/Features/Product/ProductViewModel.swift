import Foundation

@MainActor
final class ProductViewModel: ObservableObject {
    @Published var product: Product?
    @Published var priceHistory: PriceHistoryResponse?
    @Published var isLoading = false
    @Published var error: String?

    private let api = APIClient.shared

    func load(uuid: String, cityId: Int) async {
        isLoading = true
        error = nil

        let cityParam = URLQueryItem(name: "city_id", value: String(cityId))

        async let productData = api.fetch(Product.self, path: Endpoint.product(uuid), queryItems: [cityParam])
        async let historyData = api.fetch(PriceHistoryResponse.self, path: Endpoint.priceHistory(uuid), queryItems: [cityParam])

        do {
            let (p, h) = try await (productData, historyData)
            product = p
            priceHistory = h
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
