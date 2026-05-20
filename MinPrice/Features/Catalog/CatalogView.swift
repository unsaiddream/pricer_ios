import SwiftUI

private let catalogGridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct CatalogView: View {
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var vm = CatalogViewModel()

    var body: some View {
        NavigationStack {
            CategoryGridView(
                categories: vm.categories,
                onRefresh: { await vm.refreshCategories() }
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
        }
    }
}

// MARK: - Category Grid

private struct CategoryGridView: View {
    let categories: [Category]
    let onRefresh: () async -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                BrandTitle(text: "Каталог",
                           eyebrow: "Выбирайте по категориям")
                HStack(spacing: 8) {
                    if !categories.isEmpty {
                        AppMetricPill(
                            icon: "square.grid.2x2.fill",
                            text: "\(categories.count) \(categoriesWord(categories.count))",
                            tint: Color.appPrimary
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)

            AppSectionHeader(
                title: "Категории",
                subtitle: "Быстрый вход в разделы",
                icon: "square.grid.2x2.fill",
                accent: Color.appPrimary
            )
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

private struct CategoryCard: View {
    let category: Category
    let color: Color

    private var emoji: String {
        category.emoji ?? fallbackEmoji(for: category.name)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.14))
                Circle().stroke(color.opacity(0.28), lineWidth: 1)
                Text(emoji)
                    .font(.system(size: 28))
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("Смотреть товары")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 92)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color.opacity(0.95))
                .frame(width: 4)
                .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .frame(height: 92)
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
                HStack(spacing: 10) {
                    AppSectionHeader(
                        title: category.name,
                        subtitle: vm.filteredProducts.isEmpty ? nil : "\(vm.filteredProducts.count) товаров",
                        icon: "basket.fill",
                        accent: Color.appPrimary
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)

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
                                ProductCardWrapper(product: product)
                            }
                            .buttonStyle(.pressScale)
                            .onAppear {
                                guard vm.searchQuery.isEmpty else { return }
                                guard product.uuid == vm.filteredProducts.last?.uuid else { return }
                                Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if vm.isLoading {
                        PaginationLoader()
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
