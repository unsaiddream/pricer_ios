import SwiftUI
import Kingfisher

private let catalogGridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct CatalogView: View {
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var vm = CatalogViewModel()
    @State private var brandSearchItem: BrandSearchItem? = nil

    var body: some View {
        NavigationStack {
            CategoryGridView(
                categories: vm.categories,
                onRefresh: { await vm.refreshCategories() },
                onBrandTap: { brand in brandSearchItem = BrandSearchItem(brand: brand) }
            )
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .task { await vm.loadCategories() }
            .navigationDestination(for: Category.self) { category in
                CatalogProductsView(vm: vm, category: category)
                    .task { await vm.selectCategory(category, cityId: cityStore.selectedCityId) }
            }
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .fullScreenCover(item: $brandSearchItem) { item in
                BrandProductsView(brand: item.brand)
            }
        }
    }
}

// Запасной список популярных брендов — используется если RemoteConfig не пришёл.
// Бэкенд может перезаписать через AppConfig.popularBrands.
private let fallbackPopularBrands: [AppConfig.PopularBrand] = [
    .init(name: "Coca-Cola",     emoji: "🥤", logoUrl: nil),
    .init(name: "Rakhat",        emoji: "🍫", logoUrl: nil),
    .init(name: "Lay's",         emoji: "🍟", logoUrl: nil),
    .init(name: "Простоквашино", emoji: "🥛", logoUrl: nil),
    .init(name: "Nescafé",       emoji: "☕", logoUrl: nil),
    .init(name: "Lipton",        emoji: "🍵", logoUrl: nil),
    .init(name: "Pepsi",         emoji: "🥤", logoUrl: nil),
    .init(name: "Barilla",       emoji: "🍝", logoUrl: nil),
]

// MARK: - Category Grid

private struct CategoryGridView: View {
    let categories: [Category]
    let onRefresh: () async -> Void
    let onBrandTap: (String) -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            // Header — title + contextual subtitle
            VStack(alignment: .leading, spacing: 3) {
                BrandTitle(text: "Каталог")
                HStack(spacing: 6) {
                    if !categories.isEmpty {
                        Text("\(categories.count) \(categoriesWord(categories.count))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.appPrimary)
                    }
                    Text("·")
                        .foregroundStyle(Color.appMuted.opacity(0.5))
                    Text("выбирайте категорию или бренд")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color.appMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)

            // Brand strip — quick entry into BrandProductsView
            BrandStrip(onTap: onBrandTap)
                .padding(.bottom, 20)

            // Section label for categories
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appPrimary)
                    .frame(width: 3, height: 16)
                Text("Категории")
                    .font(.jb(15, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            if categories.isEmpty {
                SkeletonCategoryGrid()
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                        NavigationLink(value: cat) {
                            CategoryCard(
                                category: cat,
                                color: BrandPalette.categoryPalette[idx % BrandPalette.categoryPalette.count]
                            )
                        }
                        .buttonStyle(.pressScale)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 160)
            }
        }
        .refreshable { await onRefresh() }
        .background(Color.appBackground)
    }

    private func categoriesWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "категорий" }
        if m10 == 1 { return "категория" }
        if m10 >= 2 && m10 <= 4 { return "категории" }
        return "категорий"
    }
}

// MARK: - Brand Strip

private struct BrandStrip: View {
    let onTap: (String) -> Void
    @ObservedObject private var configStore = RemoteConfigStore.shared

    /// Источник правды — RemoteConfig.popularBrands. Если бэкенд ничего не вернул,
    /// используем встроенный fallback. Так бэк может в любой момент перетасовать
    /// или добавить бренды без релиза приложения.
    private var brands: [AppConfig.PopularBrand] {
        if let remote = configStore.config.popularBrands, !remote.isEmpty {
            return remote
        }
        return fallbackPopularBrands
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.discountRed)
                    .frame(width: 3, height: 16)
                Text("Популярные бренды")
                    .font(.jb(15, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(brands, id: \.name) { item in
                        Button { onTap(item.name) } label: {
                            HStack(spacing: 7) {
                                if let logo = item.logoUrl, let url = URL(string: logo) {
                                    KFImage(url)
                                        .downsampled(to: CGSize(width: 18, height: 18))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                } else if let emoji = item.emoji {
                                    Text(emoji)
                                        .font(.system(size: 16))
                                }
                                Text(item.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.appForeground)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.appCard, in: Capsule())
                            .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct CategoryCard: View {
    let category: Category
    let color: Color

    private var emoji: String {
        category.emoji ?? fallbackEmoji(for: category.name)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Лёгкий цветной градиент-акцент в углу — без blur (blur на 30+ карточках лагает)
            RadialGradient(
                colors: [color.opacity(0.22), color.opacity(0.0)],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 90
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(emoji)
                    .font(.system(size: 40))

                Spacer()

                Text(category.name)
                    .font(.jb(12, weight: .semibold))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private func fallbackEmoji(for name: String) -> String {
        let pairs: [(String, String)] = [
            ("Молочн", "🥛"), ("Хлеб", "🍞"), ("Овощ", "🥦"), ("Фрукт", "🍎"),
            ("Яйц", "🥚"), ("Мясо", "🥩"), ("Птиц", "🍗"), ("Рыб", "🐟"),
            ("Морепрод", "🦐"), ("Заморож", "🧊"), ("Бакалея", "🌾"),
            ("Крупы", "🌾"), ("Масл", "🫙"), ("Консерв", "🥫"),
            ("Снек", "🍿"), ("Сладост", "🍫"), ("Шоколад", "🍫"),
            ("Печень", "🍪"), ("Мороженое", "🍦"), ("Напиток", "🧃"),
            ("Вода", "💧"), ("Сок", "🍹"), ("Чай", "🍵"), ("Кофе", "☕"),
            ("Алкоголь", "🍷"), ("Пиво", "🍺"), ("Готов", "🥡"),
            ("Детск", "👶"), ("Бытов", "🧹"), ("Красот", "💄"),
            ("Уход", "🧴"), ("Зоо", "🐾"), ("Эко", "🌿"),
        ]
        for (key, emoji) in pairs {
            if name.localizedCaseInsensitiveContains(key) { return emoji }
        }
        return "🛍️"
    }
}

private struct SkeletonCategoryGrid: View {
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private let skeletonColor = Color.appBorder.opacity(0.6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18)
                    .fill(skeletonColor)
                    .frame(height: 120)
                    .shimmer()
            }
        }
    }
}

// MARK: - Products View

private struct CatalogProductsView: View {
    @ObservedObject var vm: CatalogViewModel
    let category: Category

    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var cityStore: CityStore
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search + Sort header
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appMuted)
                    TextField("Поиск в категории...", text: $vm.searchQuery)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appForeground)
                        .focused($searchFocused)
                    if !vm.searchQuery.isEmpty {
                        Button { vm.searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.appMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                    searchFocused ? Color.appPrimary.opacity(0.5) : Color.appBorder,
                    lineWidth: 1
                ))
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CatalogSort.allCases, id: \.self) { option in
                            Button { vm.sort = option } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: sortIcon(for: option))
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(option.rawValue)
                                        .font(.jb(12, weight: .medium))
                                }
                                .foregroundStyle(vm.sort == option ? .white : Color.appForeground)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    vm.sort == option ? Color.appPrimary : Color.appCard,
                                    in: Capsule()
                                )
                                .overlay(Capsule().stroke(
                                    vm.sort == option ? Color.clear : Color.appBorder,
                                    lineWidth: 1
                                ))
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.15), value: vm.sort)
                        }

                        if !vm.filteredProducts.isEmpty {
                            Text("\(vm.filteredProducts.count) товаров")
                                .font(.jb(12))
                                .foregroundStyle(Color.appMuted)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.appBackground)

            Divider().overlay(Color.appBorder)

            // Products grid
            ScrollView {
                if vm.products.isEmpty && vm.isLoading {
                    SkeletonCardGrid(count: 6)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if vm.filteredProducts.isEmpty && !vm.searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.appMuted.opacity(0.4))
                        Text("Ничего не найдено")
                            .font(.jb(15, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                        Text("Попробуйте другой запрос")
                            .font(.jb(13))
                            .foregroundStyle(Color.appMuted.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: catalogGridColumns, spacing: 10) {
                        ForEach(vm.filteredProducts) { product in
                            NavigationLink(value: product.uuid) {
                                ProductCard(product: product) {
                                    Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                }.equatable()
                            }
                            .buttonStyle(.pressScale)
                            .onAppear {
                                if product.uuid == vm.products.last?.uuid {
                                    Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if vm.isLoading {
                        ProgressView()
                            .tint(Color.appPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }

                Color.clear.frame(height: 160)
            }
            .background(Color.appBackground)
            .scrollDismissesKeyboard(.immediately)
            .refreshable {
                await vm.selectCategory(category, cityId: cityStore.selectedCityId)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sortIcon(for sort: CatalogSort) -> String {
        switch sort {
        case .priceAsc:  return "arrow.up"
        case .priceDesc: return "arrow.down"
        case .discount:  return "tag"
        }
    }
}
