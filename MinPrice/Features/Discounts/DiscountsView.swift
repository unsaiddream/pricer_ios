import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct DiscountsView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                // Переключатель режима
                ModePicker(selected: $vm.mode)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

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
                                }
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if product.uuid == vm.products.last?.uuid {
                                    Task { await vm.load(cityId: cityStore.selectedCityId, append: true) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    if vm.isLoading {
                        ProgressView().tint(Color.appPrimary).padding()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Скидки")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Mode Picker

private struct ModePicker: View {
    @Binding var selected: DiscountsMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(DiscountsMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = mode }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.jb(12, weight: .semibold))
                    }
                    .foregroundStyle(selected == mode ? .white : Color.appMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        if selected == mode {
                            Capsule().fill(modeColor(mode))
                        } else {
                            Capsule().fill(Color.appCard)
                                .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func modeColor(_ mode: DiscountsMode) -> Color {
        switch mode {
        case .discounts:     return Color.appPrimary
        case .priceDrops:    return .green
        case .priceIncreases: return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }
}
