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
        if append && !hasMore { return }   // не дочитываем после конца
        isLoading = true

        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]

        do {
            let r = try await api.fetch(DiscountsResponse.self, path: Endpoint.discounts(), queryItems: items)
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
            hasMore = page < r.totalPages
            if hasMore { page += 1 }
        } catch {}

        isLoading = false
    }

    func refresh(cityId: Int) async {
        // Не очищаем products[] до получения свежих — иначе LazyVGrid рушится
        // в transition (items disappear → reappear), особенно когда параллельно
        // фоновый loadMore по .onAppear пытается дочитать пагинацию.
        page = 1
        hasMore = false
        await load(cityId: cityId, append: false)
    }
}
