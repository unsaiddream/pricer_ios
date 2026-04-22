import SwiftUI
import Kingfisher

struct CartView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = CartViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.summary == nil {
                    SkeletonRowList(count: 5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 16)
                } else if let summary = vm.summary, !summary.cheapestPerProduct.isEmpty {
                    CartSummaryView(summary: summary, vm: vm) { productUuid in
                        guard let cart = cartStore.cart else { return }
                        Task { await vm.removeItem(cart: cart, productUuid: productUuid, cityId: cityStore.selectedCityId) }
                    }
                } else {
                    EmptyCartView()
                }
            }
            .navigationTitle("Корзина")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.appBackground)
            .toolbar {
                if let cart = cartStore.cart, vm.summary != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: URL(string: "https://minprice.kz/cart/\(cart.uuid)")!) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.appPrimary)
                        }
                    }
                }
            }
        }
        .task {
            await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
            await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId)
        }
        .onChange(of: cartStore.cart?.uuid) { _ in
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
        .onChange(of: cartStore.itemsCount) { _ in
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
    }
}

// MARK: - Empty state

private struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 52))
                .foregroundStyle(Color.appMuted.opacity(0.5))
            Text("Корзина пуста")
                .font(.jb(18, weight: .bold))
                .foregroundStyle(Color.appForeground)
            Text("Добавляйте товары из поиска или каталога")
                .font(.jb(14))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Summary view

private struct CartSummaryView: View {
    let summary: CartSummaryResponse
    let vm: CartViewModel
    let onRemove: (String) -> Void

    @EnvironmentObject var cityStore: CityStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Итоговая сумма
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Минимальная сумма")
                            .font(.jb(12))
                            .foregroundStyle(Color.appMuted)
                        Text("\(Int(summary.cheapestTotalPrice)) ₸")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.appForeground)
                    }
                    Spacer()
                    Text("\(summary.totalItems) товаров")
                        .font(.jb(13))
                        .foregroundStyle(Color.appMuted)
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))

                // Список товаров
                VStack(alignment: .leading, spacing: 10) {
                    Text("Лучшие цены")
                        .font(.jb(15, weight: .semibold))
                        .foregroundStyle(Color.appForeground)

                    VStack(spacing: 0) {
                        ForEach(Array(summary.cheapestPerProduct.enumerated()), id: \.element.product.uuid) { idx, item in
                            CartItemRow(item: item, onRemove: { onRemove(item.product.uuid) })
                            if idx < summary.cheapestPerProduct.count - 1 {
                                Divider().overlay(Color.appBorder).padding(.leading, 80)
                            }
                        }
                    }
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
                }

                // Сравнение по магазинам
                if !summary.singleStoreTotals.isEmpty {
                    StoreComparisonSection(totals: summary.singleStoreTotals, vm: vm)
                }

                // Недоступные товары
                if !summary.unavailableProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Нет в наличии")
                            .font(.jb(15, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                        ForEach(summary.unavailableProducts, id: \.product.uuid) { item in
                            HStack(spacing: 12) {
                                KFImage(item.product.coverURL)
                                    .resizable().scaledToFit()
                                    .frame(width: 44, height: 44)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(item.product.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.appMuted)
                                    .lineLimit(2)
                            }
                            .opacity(0.5)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Cart item row

private struct CartItemRow: View {
    let item: CartSummaryStoreItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            KFImage(item.product.coverURL)
                .placeholder { Rectangle().fill(Color.appBackground) }
                .resizable().scaledToFit()
                .frame(width: 56, height: 56)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    StoreLogoView(url: nil, source: item.chainSource, size: 14)
                    Text(item.chainName ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(item.itemTotal)) ₸")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Text("×\(item.quantity)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onRemove) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Store comparison

private struct StoreComparisonSection: View {
    let totals: [SingleStoreTotal]
    let vm: CartViewModel

    @EnvironmentObject var cityStore: CityStore
    @State private var transferringSource: String? = nil

    private let transferableChains: Set<String> = ["arbuz", "airbafresh", "mgo"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Если купить в одном магазине")
                .font(.jb(15, weight: .semibold))
                .foregroundStyle(Color.appForeground)

            VStack(spacing: 0) {
                ForEach(Array(totals.enumerated()), id: \.element.id) { idx, store in
                    HStack(spacing: 12) {
                        StoreLogoView(url: nil, source: store.chainSource, size: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.chainName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.appForeground)
                            Text("\(store.availableCount) из \(store.totalCount) товаров")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appMuted)
                        }

                        Spacer()

                        Text("\(Int(store.totalPrice)) ₸")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.appForeground)

                        if transferableChains.contains(store.chainSource) {
                            Button {
                                Task {
                                    transferringSource = store.chainSource
                                    if let url = await vm.transferToStore(
                                        chainSource: store.chainSource,
                                        items: store.products,
                                        cityId: cityStore.selectedCityId
                                    ) {
                                        await UIApplication.shared.open(url)
                                    }
                                    transferringSource = nil
                                }
                            } label: {
                                if transferringSource == store.chainSource {
                                    ProgressView().tint(Color.appPrimary).frame(width: 32)
                                } else {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.appPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if idx < totals.count - 1 {
                        Divider().overlay(Color.appBorder).padding(.leading, 58)
                    }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
        }
    }
}
