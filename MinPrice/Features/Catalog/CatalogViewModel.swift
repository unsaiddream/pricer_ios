import Foundation

enum CatalogSort: String, CaseIterable {
    case priceAsc  = "Дешевле"
    case priceDesc = "Дороже"
    case discount  = "Скидки"
}

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var page = 1
    @Published var hasMore = false
    @Published var sort: CatalogSort = .priceAsc
    @Published var searchQuery: String = ""

    private let api = APIClient.shared
    private var currentCategory: Category?

    var filteredProducts: [Product] {
        let base = searchQuery.isEmpty ? products : products.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery)
        }
        switch sort {
        case .priceAsc:
            return base.sorted { ($0.cheapestPrice ?? .infinity) < ($1.cheapestPrice ?? .infinity) }
        case .priceDesc:
            return base.sorted { ($0.cheapestPrice ?? 0) > ($1.cheapestPrice ?? 0) }
        case .discount:
            return base.sorted { discountPct($0) > discountPct($1) }
        }
    }

    private func discountPct(_ p: Product) -> Double {
        if let stores = p.stores,
           let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
           let prev = best.previousPrice, prev > best.price {
            return (prev - best.price) / prev * 100
        }
        if let stores = p.priceRange?.stores,
           let best = stores.filter({ $0.inStock }).min(by: { $0.price < $1.price }),
           let prev = best.previousPrice, prev > best.price {
            return (prev - best.price) / prev * 100
        }
        return 0
    }

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
        currentCategory = category
        products = []
        page = 1
        hasMore = false
        searchQuery = ""
        sort = .priceAsc
        await loadProducts(category: category, cityId: cityId, append: false)
    }

    func loadMore(cityId: Int) async {
        guard hasMore, !isLoading, let cat = currentCategory else { return }
        await loadProducts(category: cat, cityId: cityId, append: true)
    }

    private func loadProducts(category: Category, cityId: Int, append: Bool) async {
        isLoading = true

        let q = String(category.name.prefix(6))
        let items = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "canonical_category", value: category.name),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page - 1)),
            URLQueryItem(name: "hitsPerPage", value: "20"),
        ]

        do {
            let response = try await api.fetch(SearchResponse.self, path: Endpoint.search(), queryItems: items)
            if append { products += response.hits } else { products = response.hits }
            hasMore = response.page + 1 < response.nbPages
            if hasMore { page += 1 }
        } catch {
            await loadProductsFallback(category: category, cityId: cityId, append: append)
        }

        isLoading = false
    }

    private func loadProductsFallback(category: Category, cityId: Int, append: Bool) async {
        let items = [
            URLQueryItem(name: "canonical_category", value: String(category.id)),
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
