import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct DiscountsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    BrandTitle(text: "Скидки",
                               eyebrow: "Сегодня выгодно",
                               accent: Color.discountRed)
                    if !vm.products.isEmpty {
                        HStack(spacing: 8) {
                            AppMetricPill(
                                icon: "tag.fill",
                                text: "\(displayCount) \(discountsWord(displayCount))",
                                tint: Color.discountRed
                            )
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                if vm.isLoading && vm.products.isEmpty {
                    SkeletonCardGrid()
                        .padding(.vertical, 12)
                } else if vm.products.isEmpty && !vm.isLoading {
                    ErrorStateView(
                        .empty(
                            title: "Скидок пока нет",
                            message: "Обновите раздел чуть позже",
                            systemImage: "tag.slash"
                        ),
                        retry: { Task { await vm.refresh(cityId: cityStore.selectedCityId) } }
                    )
                    .padding(.top, 48)
                } else {
                    AppSectionHeader(
                        title: "Все предложения",
                        subtitle: "Отсортировано по выгоде",
                        icon: "flame.fill",
                        accent: Color.discountRed
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(vm.products) { product in
                            NavigationLink(value: product.uuid) {
                                ProductCardWrapper(product: product)
                            }
                            .buttonStyle(.pressScale)
                            .onAppear {
                                guard product.uuid == vm.products.last?.uuid else { return }
                                Task { await vm.load(cityId: cityStore.selectedCityId, append: true) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    if vm.isLoading {
                        PaginationLoader()
                    }
                }

                Color.clear.frame(height: 150)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .refreshable {
                await vm.refresh(cityId: cityStore.selectedCityId)
            }
        }
        .task {
            await vm.load(cityId: cityStore.selectedCityId)
        }
        .onChange(of: cityStore.selectedCityId) { newId in
            Task { await vm.refresh(cityId: newId) }
        }
    }

    private var displayCount: Int {
        vm.totalCount > 0 ? vm.totalCount : vm.products.count
    }

    private func discountsWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "скидок" }
        if m10 == 1 { return "скидка" }
        if m10 >= 2 && m10 <= 4 { return "скидки" }
        return "скидок"
    }
}
