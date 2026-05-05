import Foundation
import Combine

enum CatalogSort: String, CaseIterable {
    case priceAsc  = "Дешевле"
    case priceDesc = "Дороже"
    case discount  = "Скидки"
}

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var products: [Product] = [] {
        didSet { recomputeFiltered() }
    }
    @Published var isLoading = false
    @Published var page = 1
    @Published var hasMore = false
    @Published var sort: CatalogSort = .priceAsc {
        didSet { recomputeFiltered() }
    }
    @Published var searchQuery: String = "" {
        didSet { recomputeFiltered() }
    }
    // Кэш — пересчитывается только при изменении products/sort/searchQuery
    @Published private(set) var filteredProducts: [Product] = []

    private let api = APIClient.shared
    private var currentCategory: Category?

    private func recomputeFiltered() {
        let base = searchQuery.isEmpty ? products : products.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery)
        }
        switch sort {
        case .priceAsc:
            filteredProducts = base.sorted { ($0.cheapestPrice ?? .infinity) < ($1.cheapestPrice ?? .infinity) }
        case .priceDesc:
            filteredProducts = base.sorted { ($0.cheapestPrice ?? 0) > ($1.cheapestPrice ?? 0) }
        case .discount:
            filteredProducts = base.sorted { discountPct($0) > discountPct($1) }
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
        // Если уже выбрана эта же категория — не сбрасываем state (защита от
        // повторного входа через NavigationLink, чтобы не было thrash'а грида).
        if currentCategory?.id == category.id, !products.isEmpty { return }
        currentCategory = category
        page = 1
        hasMore = false
        searchQuery = ""
        sort = .priceAsc
        // products очищается атомарно в mergeProducts(append: false) после ответа.
        // Не делаем products = [] здесь, иначе LazyVGrid дёргается на transition.
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
            mergeProducts(response.hits, append: append)
            hasMore = response.page + 1 < response.nbPages
            if hasMore { page += 1 }
        } catch {
            await loadProductsFallback(category: category, cityId: cityId, append: append)
        }

        isLoading = false
    }

    private func loadProductsFallback(category: Category, cityId: Int, append: Bool) async {
        let items = [
            URLQueryItem(name: "canonical_category_id", value: String(category.id)),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
        ]
        do {
            let response = try await api.fetch(ProductsResponse.self, path: Endpoint.products(), queryItems: items)
            mergeProducts(response.results, append: append)
            hasMore = response.next != nil
            if hasMore { page += 1 }
        } catch {}
    }

    /// Дедуп по UUID при append — иначе ForEach в LazyVGrid падает с
    /// "ID ... occurs multiple times within the collection" если бэк
    /// вернул один товар на двух страницах.
    private func mergeProducts(_ incoming: [Product], append: Bool) {
        if append {
            let existing = Set(products.map(\.uuid))
            let fresh = incoming.filter { !existing.contains($0.uuid) }
            products = products + fresh
        } else {
            products = incoming
        }
    }
}
