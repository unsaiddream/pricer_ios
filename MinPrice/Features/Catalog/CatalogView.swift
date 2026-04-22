import SwiftUI

private let catalogGridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

// MARK: - Animated gradient background

private struct AnimatedGradientBackground: View {
    @State private var phase: Double = 0

    private let colors: [[Color]] = [
        [Color(red: 0.55, green: 0.87, blue: 1.0), Color(red: 0.18, green: 0.65, blue: 0.95), Color(red: 0.35, green: 0.78, blue: 1.0)],
        [Color(red: 0.35, green: 0.78, blue: 1.0), Color(red: 0.55, green: 0.90, blue: 0.98), Color(red: 0.15, green: 0.58, blue: 0.90)],
        [Color(red: 0.18, green: 0.65, blue: 0.95), Color(red: 0.40, green: 0.85, blue: 1.0), Color(red: 0.25, green: 0.70, blue: 0.95)],
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idx = Int(t / 3) % colors.count
            let next = (idx + 1) % colors.count
            let frac = (t.truncatingRemainder(dividingBy: 3)) / 3

            ZStack {
                LinearGradient(
                    colors: colors[idx],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: colors[next],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(frac)
            }
        }
        .ignoresSafeArea()
    }
}

struct CatalogView: View {
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var vm = CatalogViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.selectedCategory == nil {
                    CategoryGridView(
                        categories: vm.categories,
                        onSelect: { category in
                            Task { await vm.selectCategory(category, cityId: cityStore.selectedCityId) }
                        },
                        onRefresh: { await vm.refreshCategories() }
                    )
                } else {
                    CatalogProductsView(
                        category: vm.selectedCategory!,
                        products: vm.products,
                        isLoading: vm.isLoading,
                        onLoadMore: { Task { await vm.loadMore(cityId: cityStore.selectedCityId) } },
                        onRefresh: {
                            await vm.selectCategory(vm.selectedCategory!, cityId: cityStore.selectedCityId)
                        },
                        onBack: { vm.selectedCategory = nil }
                    )
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Каталог")
                        .font(.jb(20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .task { await vm.loadCategories() }
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
        }
    }
}

// MARK: - Category Grid

private let categoryPalette: [Color] = [
    .red, .orange, .green, .blue, .purple,
    .pink, .teal, .indigo, .yellow, .mint,
    .cyan, .brown
]

private struct CategoryGridView: View {
    let categories: [Category]
    let onSelect: (Category) -> Void
    let onRefresh: () async -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            if categories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { idx, cat in
                        Button { onSelect(cat) } label: {
                            CategoryCard(
                                category: cat,
                                color: categoryPalette[idx % categoryPalette.count]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .refreshable { await onRefresh() }
        .background(AnimatedGradientBackground())
    }
}

private struct CategoryCard: View {
    let category: Category
    let color: Color

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

            // Большое эмодзи как декор в углу
            Text(category.emoji ?? fallbackEmoji(for: category.name))
                .font(.system(size: 52))
                .opacity(0.25)
                .offset(x: 10, y: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.emoji ?? fallbackEmoji(for: category.name))
                    .font(.system(size: 28))
                Spacer()
                Text(category.name)
                    .font(.jb(12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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

// MARK: - Products List

private struct CatalogProductsView: View {
    let category: Category
    let products: [Product]
    let isLoading: Bool
    let onLoadMore: () -> Void
    let onRefresh: () async -> Void
    let onBack: () -> Void

    @EnvironmentObject var cartStore: CartStore

    private var navTitle: String { category.name }

    var body: some View {
        ScrollView {
            if products.isEmpty && isLoading {
                SkeletonCardGrid(count: 6)
                    .padding(.top, 8)
            } else {
                LazyVGrid(columns: catalogGridColumns, spacing: 10) {
                    ForEach(products) { product in
                        NavigationLink(value: product.uuid) {
                            ProductCard(product: product) {
                                Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if product.uuid == products.last?.uuid { onLoadMore() }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
        .padding(.bottom, 160)
        .refreshable { await onRefresh() }
        .background(Color.appBackground)
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Каталог")
                    }
                    .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}
