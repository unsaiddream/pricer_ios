import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var bestDeals: [Product] = []
    @Published var bestDealsTotal: Int?
    @Published var priceDrops: [Product] = []
    @Published var hasMoreBestDeals = false
    @Published var hasMorePriceDrops = false
    @Published var isLoadingMoreBestDeals = false
    @Published var isLoadingMorePriceDrops = false
    @Published var categories: [Category] = []
    @Published var basketCategory: Category?
    /// Готовый агрегат с бэка для графика-корзины — приоритетный источник.
    /// Если null, чарт упадёт на легаси-путь (basketProducts + клиентский precompute).
    @Published var basketSummary: StoreBasketResponse?
    /// Легаси: список товаров для клиентской агрегации. Используется только когда
    /// `basketSummary` == nil (т.е. эндпоинт /home/basket/ ещё не готов или упал).
    @Published var basketProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared
    private let homePageSize = 20
    private var bestDealsPage = 1
    private var priceDropsPage = 1

    func load(cityId: Int) async {
        // Скрываем скелетон как только пришла ПЕРВАЯ пачка (deals или drops).
        // Раньше ждали ВСЕ запросы — basket мог тащить экран ещё 1.5–2с.
        isLoading = bestDeals.isEmpty && priceDrops.isEmpty
        errorMessage = nil
        bestDealsTotal = nil
        bestDealsPage = 1
        priceDropsPage = 1
        hasMoreBestDeals = false
        hasMorePriceDrops = false

        // Категории, deals, drops — все параллельно, независимо друг от друга.
        let needCategories = categories.isEmpty
        async let categoriesResult: [Category]? = {
            guard needCategories else { return nil }
            return (try? await api.fetch(CategoriesResponse.self, path: Endpoint.categories()))?.categories
        }()

        async let dealsResult: Result<Void, Error> = {
            do {
                try await fetchBestDeals(cityId: cityId, page: 1, append: false)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()

        async let dropsResult: Result<Void, Error> = {
            do {
                try await fetchPriceDrops(cityId: cityId, page: 1, append: false)
                return .success(())
            } catch {
                return .failure(error)
            }
        }()

        // 1) Категории первыми — нужны для basket-rotation
        if let cats = await categoriesResult { categories = cats }

        // 2) Запускаем basket-загрузку в параллель с ожиданием deals/drops
        let basketTask = Task { await loadDailyBasket(cityId: cityId) }

        // 3) Ждём deals — как только пришли, показываем сетку
        let deals = await dealsResult
        switch deals {
        case .success:
            break
        case .failure(let e):
            if !e.isCancellation { errorMessage = e.localizedDescription }
        }
        if !Task.isCancelled { isLoading = false }

        // 4) Drops в фоне (UI уже показан)
        let drops = await dropsResult
        switch drops {
        case .success:
            break
        case .failure: priceDrops = []
        }

        // 5) Дожидаемся basket чтобы не оборвать его при выходе из метода
        await basketTask.value
    }

    func loadMoreBestDeals(cityId: Int) async {
        guard hasMoreBestDeals, !isLoadingMoreBestDeals else { return }
        isLoadingMoreBestDeals = true
        defer { isLoadingMoreBestDeals = false }
        do {
            try await fetchBestDeals(cityId: cityId, page: bestDealsPage + 1, append: true)
        } catch {}
    }

    func loadMorePriceDrops(cityId: Int) async {
        guard hasMorePriceDrops, !isLoadingMorePriceDrops else { return }
        isLoadingMorePriceDrops = true
        defer { isLoadingMorePriceDrops = false }
        do {
            try await fetchPriceDrops(cityId: cityId, page: priceDropsPage + 1, append: true)
        } catch {}
    }

    private func fetchBestDeals(cityId: Int, page: Int, append: Bool) async throws {
        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(homePageSize)),
        ]
        let r = try await api.fetch(BestDealsResponse.self, path: Endpoint.bestDeals(), queryItems: items)
        let selectedChainIds = Self.selectedChainIdsFromDefaults()
        let pageDeals: [Product]
        if selectedChainIds.isEmpty {
            pageDeals = r.deals
            bestDealsTotal = r.total
        } else {
            // Fallback: /best-deals/ на текущем бэке не всегда применяет chain_ids.
            // Чтобы фильтр магазинов на главной работал предсказуемо, отфильтровываем
            // клиентом по наличию выбранной сети в stores.
            pageDeals = r.deals.filter { product in
                guard let stores = product.stores, !stores.isEmpty else { return false }
                return stores.contains { selectedChainIds.contains($0.chainId) }
            }
            // Точный total при клиентском fallback неизвестен до полного обхода.
            bestDealsTotal = nil
        }
        var appendedFreshCount: Int? = nil
        if append {
            let existing = Set(bestDeals.map(\.uuid))
            let fresh = pageDeals.filter { !existing.contains($0.uuid) }
            bestDeals += fresh
            appendedFreshCount = fresh.count
        } else {
            bestDeals = pageDeals
        }
        bestDealsPage = page
        if selectedChainIds.isEmpty, let total = r.total, total > 0 {
            hasMoreBestDeals = bestDeals.count < total
        } else if let totalPages = r.totalPages {
            hasMoreBestDeals = page < totalPages
        } else {
            hasMoreBestDeals = pageDeals.count >= homePageSize
        }
        if append, appendedFreshCount == 0 {
            hasMoreBestDeals = false
        }
    }

    private static func selectedChainIdsFromDefaults() -> Set<Int> {
        let raw = UserDefaults.standard.string(forKey: "minprice_favorite_chains_csv") ?? ""
        let ids = raw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return Set(ids)
    }

    private func fetchPriceDrops(cityId: Int, page: Int, append: Bool) async throws {
        let items = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(homePageSize)),
        ]
        let r = try await api.fetch(DiscountsResponse.self, path: Endpoint.discounts(), queryItems: items)
        if append {
            let existing = Set(priceDrops.map(\.uuid))
            let fresh = r.results.filter { !existing.contains($0.uuid) }
            priceDrops += fresh
        } else {
            priceDrops = r.results
        }
        priceDropsPage = page
        hasMorePriceDrops = page < r.totalPages
    }

    /// Категория дня — пытаемся получить готовый агрегат с бэка.
    /// Если эндпоинт ещё не задеплоен или вернул ошибку — fallback на старую
    /// схему (3-12 запросов + клиентский precompute).
    private func loadDailyBasket(cityId: Int) async {
        // Сначала просим бэк выбрать категорию (rotation на стороне сервера)
        if await fetchBasketSummary(cityId: cityId, categoryId: nil, period: "now") {
            return
        }
        // Fallback — клиентская ротация
        let pool = pickRotationPool()
        guard !pool.isEmpty else { return }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let category = pool[day % pool.count]
        await loadBasket(for: category, cityId: cityId)
    }

    /// Внешний триггер — пользователь выбрал категорию из строки.
    func selectBasketCategory(_ category: Category, cityId: Int) async {
        basketCategory = category
        if await fetchBasketSummary(cityId: cityId, categoryId: category.id, period: "now") {
            return
        }
        await loadBasket(for: category, cityId: cityId)
    }

    /// Сброс категории — общий график по всем доступным товарам.
    func selectAllCategories(cityId: Int) async {
        basketCategory = nil
        // Бэк должен поддержать category_id=0 или отсутствие параметра как "все".
        if await fetchBasketSummary(cityId: cityId, categoryId: nil, period: "now") {
            return
        }
        // Fallback: клиентская агрегация поверх 12 запросов (legacy)
        await legacySelectAllCategories(cityId: cityId)
    }

    /// Один запрос к /home/basket/ — главный путь. Возвращает true при успехе.
    private func fetchBasketSummary(cityId: Int, categoryId: Int?, period: String) async -> Bool {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "period",  value: period),
        ]
        if let id = categoryId {
            items.append(URLQueryItem(name: "category_id", value: String(id)))
        }
        let r: StoreBasketResponse
        do {
            r = try await api.fetch(StoreBasketResponse.self,
                                    path: Endpoint.storeBasket(),
                                    queryItems: items,
                                    timeout: 6.0)
        } catch APIError.httpError(let code) where code == 429 {
            errorMessage = "Слишком много запросов. Подождите пару секунд и попробуйте снова."
            return true
        } catch {
            return false
        }
        basketSummary = r
        // Сбрасываем legacy-пул чтобы чарт переключился на агрегат
        basketProducts = []
        // Подсветим выбранную категорию в UI если бэк её прислал
        if let c = r.category {
            basketCategory = Category(id: c.id, name: c.name, emoji: c.emoji, level: 1, priority: 0, children: nil)
        }
        return true
    }

    /// Legacy-загрузка по конкретной категории (3 параллельных запроса).
    private func loadBasket(for category: Category, cityId: Int) async {
        basketCategory = category
        let q = String(category.name.prefix(6))

        async let searchPage0 = fetchSearch(q: q, name: category.name, cityId: cityId, page: 0)
        async let searchPage1 = fetchSearch(q: q, name: category.name, cityId: cityId, page: 1)
        async let productsFallback = fetchProductsByCategoryId(categoryId: category.id, cityId: cityId)

        let (p0, p1, pf) = await (searchPage0, searchPage1, productsFallback)

        var seen = Set<String>()
        var combined: [Product] = []
        for batch in [p0, p1, pf] {
            for product in batch {
                if seen.insert(product.uuid).inserted {
                    combined.append(product)
                }
            }
        }
        if basketCategory?.id == category.id {
            basketSummary = nil      // сигнал чарту использовать legacy-путь
            basketProducts = combined
        }
    }

    /// Legacy-«все каталоги» (12 параллельных запросов).
    private func legacySelectAllCategories(cityId: Int) async {
        var seen = Set<String>()
        var combined: [Product] = []
        for p in bestDeals + priceDrops {
            if seen.insert(p.uuid).inserted { combined.append(p) }
        }
        basketProducts = combined

        let pool = pickRotationPool().prefix(6)
        guard !pool.isEmpty else { return }

        await withTaskGroup(of: [Product].self) { group in
            for category in pool {
                let categoryName = category.name
                let q = String(categoryName.prefix(6))
                group.addTask {
                    await self.fetchSearch(q: q, name: categoryName, cityId: cityId, page: 0)
                }
                let categoryId = category.id
                group.addTask {
                    await self.fetchProductsByCategoryId(categoryId: categoryId, cityId: cityId)
                }
            }
            for await hits in group {
                for p in hits {
                    if seen.insert(p.uuid).inserted { combined.append(p) }
                }
            }
        }

        if basketCategory == nil {
            basketSummary = nil
            basketProducts = combined
        }
    }

    private func fetchSearch(q: String, name: String, cityId: Int, page: Int) async -> [Product] {
        let items = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "canonical_category", value: name),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "hitsPerPage", value: "40"),
        ]
        if let r = try? await api.fetch(SearchResponse.self, path: Endpoint.search(), queryItems: items) {
            return r.hits
        }
        return []
    }

    private func fetchProductsByCategoryId(categoryId: Int, cityId: Int) async -> [Product] {
        // /api/products/ — DRF, фильтр canonical_category_id (не canonical_category!)
        // и пагинация 1-индексированная (page=0 → 404 "Invalid page").
        let items = [
            URLQueryItem(name: "canonical_category_id", value: String(categoryId)),
            URLQueryItem(name: "city_id", value: String(cityId)),
            URLQueryItem(name: "page", value: "1"),
        ]
        if let r = try? await api.fetch(ProductsResponse.self, path: Endpoint.products(), queryItems: items) {
            return r.results
        }
        return []
    }

    /// Кандидаты для ротации — топ-уровень категорий, без эзотерики.
    private func pickRotationPool() -> [Category] {
        let topLevel = categories.filter { $0.level <= 1 }
        if topLevel.isEmpty { return categories }
        return topLevel.sorted { $0.priority < $1.priority }
    }
}
