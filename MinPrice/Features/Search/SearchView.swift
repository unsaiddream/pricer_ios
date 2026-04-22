import SwiftUI

struct SearchView: View {
    var initialQuery: String? = nil

    @EnvironmentObject var cityStore: CityStore
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.results.isEmpty && vm.query.isEmpty {
                    if vm.recentSearches.isEmpty {
                        SearchEmptyState()
                    } else {
                        RecentSearchesView(
                            searches: vm.recentSearches,
                            onSelect: { q in
                                vm.query = q
                                Task { await vm.search(cityId: cityStore.selectedCityId) }
                            },
                            onClear: { vm.clearRecent() }
                        )
                    }
                } else {
                    List {
                        ForEach(vm.results) { product in
                            NavigationLink(value: product.uuid) {
                                ProductRow(product: product)
                            }
                            .listRowBackground(Color.appCard)
                            .onAppear {
                                if product.uuid == vm.results.last?.uuid {
                                    Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                                }
                            }
                        }

                        if vm.isLoading && vm.results.isEmpty {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonProductRow()
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.appBackground)
                            }
                        } else if vm.isLoading {
                            HStack { Spacer(); ProgressView().tint(Color.appPrimary); Spacer() }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.appBackground)
                        }

                        if vm.results.isEmpty && !vm.query.isEmpty && !vm.isLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundStyle(Color.appMuted)
                                    Text("По запросу «\(vm.query)»\nничего не найдено")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appMuted)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 40)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.appBackground)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.appBackground)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("Поиск")
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .searchable(text: $vm.query, prompt: "Молоко, хлеб, сыр...")
            .onChange(of: vm.query) { _ in
                Task { await vm.search(cityId: cityStore.selectedCityId) }
            }
            .onAppear {
                if let q = initialQuery, !q.isEmpty {
                    vm.query = q
                    Task { await vm.search(cityId: cityStore.selectedCityId) }
                }
            }
        }
    }
}

private struct RecentSearchesView: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Последние запросы")
                        .font(.jb(15, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                    Spacer()
                    Button(action: onClear) {
                        Text("Очистить")
                            .font(.jb(13))
                            .foregroundStyle(Color.appPrimary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(searches.enumerated()), id: \.offset) { idx, query in
                        Button {
                            onSelect(query)
                        } label: {
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
                                    .foregroundStyle(Color.appMuted.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)

                        if idx < searches.count - 1 {
                            Divider().overlay(Color.appBorder).padding(.leading, 44)
                        }
                    }
                }
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 100)
        }
        .background(Color.appBackground)
    }
}

private struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.jb(48))
                .foregroundStyle(Color.appPrimary.opacity(0.4))
            Text("Найдите самые низкие цены")
                .font(.jb(16, weight: .semibold))
                .foregroundStyle(Color.appForeground)
            Text("Ищите товары по названию или бренду")
                .font(.jb(14))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
