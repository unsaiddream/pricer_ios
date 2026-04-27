import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct DiscountsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // Заголовок — те же отступы, что и на остальных вкладках
                BrandTitle(text: "Скидки")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                if vm.isLoading && vm.products.isEmpty {
                    SkeletonCardGrid()
                        .padding(.vertical, 12)
                } else if vm.products.isEmpty && !vm.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.appMuted.opacity(0.4))
                        Text("Нет данных")
                            .font(.jb(15))
                            .foregroundStyle(Color.appMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(vm.products) { product in
                            NavigationLink(value: product.uuid) {
                                ProductCard(product: product) {
                                    Task { try? await cartStore.quickAdd(productUuid: product.uuid) }
                                }.equatable()
                            }
                            .buttonStyle(.pressScale)
                            .onAppear {
                                if product.uuid == vm.products.last?.uuid {
                                    Task { await vm.load(cityId: cityStore.selectedCityId, append: true) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if vm.isLoading {
                        ProgressView().tint(Color.appPrimary).padding()
                    }
                }
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
}

