import Foundation

@MainActor
final class DiscountsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var totalCount = 0

    private var page = 1
    private var hasMore = false
    private var activeRequestId = UUID()
    private let api = APIClient.shared

    func load(cityId: Int, append: Bool = false) async {
        if isLoading { return }
        if append && !hasMore { return }   // не дочитываем после конца
        let requestId = activeRequestId
        isLoading = true

        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]

        do {
            let r = try await api.fetch(DiscountsResponse.self, path: Endpoint.discounts(), queryItems: items)
            guard requestId == activeRequestId else { return }
            // Бэк может вернуть товар сразу на двух страницах (особенно при сортировке
            // по discount_percent) — дедупим по UUID, иначе ForEach падает с
            // "ID occurs multiple times within the collection".
            if append {
                let existing = Set(products.map(\.uuid))
                let fresh = r.results.filter { !existing.contains($0.uuid) }
                products = products + fresh
            } else {
                products = r.results
            }
            totalCount = r.total
            hasMore = page < r.totalPages
            if hasMore { page += 1 }
        } catch {}

        if requestId == activeRequestId {
            isLoading = false
        }
    }

    func refresh(cityId: Int) async {
        // Не очищаем products[] до получения свежих — иначе LazyVGrid рушится
        // в transition (items disappear → reappear), особенно когда параллельно
        // фоновый loadMore по .onAppear пытается дочитать пагинацию.
        activeRequestId = UUID()
        isLoading = false
        page = 1
        hasMore = false
        totalCount = 0
        await load(cityId: cityId, append: false)
    }
}
