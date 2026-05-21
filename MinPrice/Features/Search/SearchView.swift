import SwiftUI

struct SearchView: View {
    var initialQuery: String? = nil
    var onDismiss: () -> Void = {}

    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = SearchViewModel()
    @FocusState private var focused: Bool
    @State private var navPath = NavigationPath()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack(spacing: 0) {
                SearchBar(
                    query: $vm.query,
                    isLoading: vm.isLoading,
                    focused: $focused,
                    onDismiss: {
                        focused = false
                        onDismiss()
                    }
                )

                Divider().overlay(Color.appBorder)

                Group {
                    if vm.results.isEmpty && vm.query.isEmpty {
                        if vm.recentSearches.isEmpty {
                            SearchEmptyState { suggestion in
                                vm.query = suggestion
                                focused = false
                                Task { await vm.searchImmediate(cityId: cityStore.selectedCityId) }
                            }
                        } else {
                            RecentSearchesView(
                                searches: vm.recentSearches,
                                onSelect: { q in
                                    vm.query = q
                                    focused = false
                                    Task { await vm.searchImmediate(cityId: cityStore.selectedCityId) }
                                },
                                onDelete: { vm.removeRecent($0) },
                                onClear: { vm.clearRecent() }
                            )
                        }
                    } else {
                        ScrollView {
                            if vm.isLoading && vm.results.isEmpty {
                                SkeletonCardGrid(count: 6)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                            } else if vm.results.isEmpty && !vm.query.isEmpty && !vm.isLoading {
                                SearchNoResults(query: vm.query)
                            } else if !vm.results.isEmpty {
                                VStack(spacing: 0) {
                                    ResultsHeader(
                                        count: vm.totalHits,
                                        sort: $vm.sort
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                    .padding(.bottom, 8)

                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(vm.sortedResults) { product in
                                            NavigationLink(value: product.uuid) {
                                                ProductCardWrapper(product: product)
                                            }
                                            .buttonStyle(.pressScale)
                                        }
                                    }
                                    .padding(.horizontal, 16)

                                    if !vm.results.isEmpty {
                                        Color.clear
                                            .frame(height: 1)
                                            .onAppear {
                                                Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                                            }
                                    }

                                    if vm.isLoading {
                                        PaginationLoader()
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Color.clear.frame(height: 40)
                        }
                        .scrollDismissesKeyboard(.immediately)
                        .animation(.easeOut(duration: 0.2), value: vm.results.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
            }
            .background(Color.appBackground)
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
        }
        .onChange(of: vm.query) { _ in
            Task { await vm.search(cityId: cityStore.selectedCityId) }
        }
        .onAppear {
            if let q = initialQuery, !q.isEmpty {
                vm.query = q
                let isBarcode = q.allSatisfy(\.isNumber) && q.count >= 8
                Task {
                    await vm.searchImmediate(cityId: cityStore.selectedCityId)
                    if isBarcode && vm.results.count == 1 {
                        navPath.append(vm.results[0].uuid)
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focused = true }
            }
        }
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @Binding var query: String
    let isLoading: Bool
    var focused: FocusState<Bool>.Binding
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.75)
                            .tint(Color.appPrimary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(focused.wrappedValue ? Color.appPrimary : Color.appMuted)
                    }
                }
                .frame(width: 18, height: 18)
                .animation(.easeInOut(duration: 0.2), value: isLoading)

                TextField("Молоко, хлеб, сыр...", text: $query)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.appForeground)
                    .focused(focused)
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appMuted)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        focused.wrappedValue ? Color.appPrimary.opacity(0.6) : Color.appBorder,
                        lineWidth: focused.wrappedValue ? 1.5 : 1
                    )
                    .animation(.easeInOut(duration: 0.18), value: focused.wrappedValue)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: query.isEmpty)

            Button("Отмена", action: onDismiss)
                .font(.jb(15))
                .foregroundStyle(Color.appPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appBackground)
    }
}

// MARK: - Results Header + Sort

private struct ResultsHeader: View {
    let count: Int
    @Binding var sort: SearchSort

    private func countLabel(_ n: Int) -> String {
        let m10 = n % 10; let m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "\(n) товаров" }
        if m10 == 1 { return "\(n) товар" }
        if m10 >= 2 && m10 <= 4 { return "\(n) товара" }
        return "\(n) товаров"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if count > 0 {
                Text(countLabel(count))
                    .font(.jb(13))
                    .foregroundStyle(Color.appMuted)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: count)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchSort.allCases) { option in
                        let active = sort == option
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                sort = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.jb(12, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? .white : Color.appForeground)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    active
                                        ? Color.appPrimary
                                        : Color.appCard,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule().stroke(
                                        active ? Color.clear : Color.appBorder,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
                    }
                }
            }
        }
    }
}

// MARK: - Recent Searches

private struct RecentSearchesView: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    AppSectionHeader(
                        title: "Последние запросы",
                        subtitle: "\(searches.count) сохранено",
                        icon: "clock.fill",
                        accent: Color.appPrimary
                    )
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                            .frame(width: 34, height: 34)
                            .background(Color.appCard, in: Circle())
                            .overlay(Circle().stroke(Color.appBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 8) {
                    ForEach(Array(searches.enumerated()), id: \.offset) { idx, query in
                        HStack(spacing: 10) {
                            Button { onSelect(query) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.appMuted)
                                    Text(query)
                                        .font(.jb(14))
                                        .foregroundStyle(Color.appForeground)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.appMuted.opacity(0.5))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation { onDelete(query) }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.appMuted)
                                    .frame(width: 26, height: 26)
                                    .background(Color.appBackground, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.appBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Empty state

private struct PopularSearch {
    let emoji: String
    let label: String
    let tint: Color
}

private let popularSearches: [PopularSearch] = [
    .init(emoji: "🥛", label: "Молоко",        tint: .blue),
    .init(emoji: "🍞", label: "Хлеб",          tint: .orange),
    .init(emoji: "🧀", label: "Сыр",           tint: .yellow),
    .init(emoji: "🥚", label: "Яйца",          tint: .yellow),
    .init(emoji: "🧴", label: "Шампунь",       tint: .teal),
    .init(emoji: "☕️", label: "Кофе",         tint: .brown),
    .init(emoji: "🍫", label: "Шоколад",       tint: .brown),
    .init(emoji: "🧹", label: "Бытовая химия", tint: .green),
]

private struct SearchEmptyState: View {
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.brandPrimary.opacity(0.12))
                            .frame(width: 86, height: 86)
                        Circle()
                            .stroke(LinearGradient.brandPrimary.opacity(0.20), lineWidth: 1)
                            .frame(width: 86, height: 86)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(LinearGradient.brandPrimary)
                    }

                    VStack(spacing: 4) {
                        Text("Найдите самые низкие цены")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.appForeground)
                        Text("Сравниваем 6 магазинов в вашем городе")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.appMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 10) {
                    AppSectionHeader(
                        title: "Популярные запросы",
                        subtitle: "Начните с частых товаров",
                        icon: "sparkle.magnifyingglass",
                        accent: Color.appPrimary
                    )
                    .padding(.horizontal, 16)

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(popularSearches, id: \.label) { item in
                            Button { onSelect(item.label) } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        // Цветной градиент на каждом тайле — пища для глаз
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [item.tint.opacity(0.20), item.tint.opacity(0.08)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(item.tint.opacity(0.30), lineWidth: 0.8)
                                            )
                                        Text(item.emoji)
                                            .font(.system(size: 26))
                                    }
                                    .frame(width: 54, height: 54)

                                    Text(item.label)
                                        .font(.jb(11, weight: .medium))
                                        .foregroundStyle(Color.appForeground.opacity(0.85))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                }
                            }
                            .buttonStyle(.pressScale)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 60)
        }
        .background(Color.appBackground)
    }
}

// MARK: - No results

private struct SearchNoResults: View {
    let query: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.appMuted.opacity(0.35))
            Text("Ничего не найдено")
                .font(.jb(16, weight: .semibold))
                .foregroundStyle(Color.appForeground)
            Text("По запросу «\(query)» нет товаров.\nПроверьте написание или попробуйте другой запрос.")
                .font(.jb(13))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity)
    }
}
