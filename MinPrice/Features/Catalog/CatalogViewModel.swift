import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var products: [Product] = []
    @Published var selectedCategory: Category?
    @Published var isLoading = false
    @Published var page = 1
    @Published var hasMore = false

    private let api = APIClient.shared

    func loadCategories() async {
        guard categories.isEmpty else { return }
        await refreshCategories()
    }

    func refreshCategories() async {
        do {
            let response = try await api.fetch(CategoriesResponse.self, path: Endpoint.categories())
            categories = response.categories
        } catch {}
    }

    func selectCategory(_ category: Category, cityId: Int) async {
        selectedCategory = category
        products = []
        page = 1
        hasMore = false
        await loadProducts(cityId: cityId, append: false)
    }

    func loadMore(cityId: Int) async {
        guard hasMore, !isLoading else { return }
        await loadProducts(cityId: cityId, append: true)
    }

    private func loadProducts(cityId: Int, append: Bool) async {
        guard let cat = selectedCategory else { return }
        isLoading = true

        // Используем /search/ — возвращает полные данные по всем магазинам (price_range)
        // q = название категории даёт хорошее совпадение
        let q = String(cat.name.prefix(6))
        let items = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "canonical_category", value: cat.name),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page - 1)),
            URLQueryItem(name: "hitsPerPage", value: "20"),
        ]

        do {
            let response = try await api.fetch(SearchResponse.self, path: Endpoint.search(), queryItems: items)
            if append {
                products += response.hits
            } else {
                products = response.hits
            }
            hasMore = response.page + 1 < response.nbPages
            if hasMore { page += 1 }
        } catch {
            // Fallback на /products/ если поиск не сработал
            await loadProductsFallback(cityId: cityId, append: append)
        }

        isLoading = false
    }

    private func loadProductsFallback(cityId: Int, append: Bool) async {
        guard let cat = selectedCategory else { return }
        let items = [
            URLQueryItem(name: "canonical_category", value: String(cat.id)),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]
        do {
            let response = try await api.fetch(ProductsResponse.self, path: Endpoint.products(), queryItems: items)
            if append { products += response.results } else { products = response.results }
            hasMore = response.next != nil
            if hasMore { page += 1 }
        } catch {}
    }
}
