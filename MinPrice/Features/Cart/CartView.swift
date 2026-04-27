import SwiftUI
import Kingfisher

struct CartView: View {
    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @StateObject private var vm = CartViewModel()
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.summary == nil {
                    SkeletonRowList(count: 5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 16)
                } else if let summary = vm.summary, !summary.cheapestPerProduct.isEmpty {
                    CartSummaryView(
                        summary: summary,
                        vm: vm,
                        cartUUID: cartStore.cart?.uuid,
                        onRemove: { productUuid in
                            guard let cart = cartStore.cart else { return }
                            Task { await vm.removeItem(cart: cart, productUuid: productUuid, cityId: cityStore.selectedCityId) }
                        },
                        onClear: { showClearConfirm = true }
                    )
                } else {
                    EmptyCartView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.appBackground)
            .confirmationDialog("Очистить корзину?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Очистить", role: .destructive) {
                    guard let cart = cartStore.cart else { return }
                    Task { await vm.clearCart(cart: cart, cityId: cityStore.selectedCityId) }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все товары будут удалены из корзины")
            }
        }
        .refreshable {
            await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
            await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId)
        }
        .task {
            await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
            await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId)
        }
        .onChange(of: cartStore.cart?.uuid) { _ in
            // Fires when cart UUID changes (new cart created)
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
        .onChange(of: cartStore.refreshCount) { _ in
            // Fires after quickAdd — reload summary to show new item
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
        .onChange(of: vm.summary?.cheapestPerProduct.count) { count in
            cartStore.itemsCount = count ?? 0
        }
    }
}

// MARK: - Empty state

private struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "cart")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appPrimary.opacity(0.5))
            }
            VStack(spacing: 8) {
                Text("Корзина пуста")
                    .font(.jb(20, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                Text("Добавляйте товары из поиска или каталога")
                    .font(.jb(14))
                    .foregroundStyle(Color.appMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Summary view

private struct CartSummaryView: View {
    let summary: CartSummaryResponse
    let vm: CartViewModel
    let cartUUID: String?
    let onRemove: (String) -> Void
    let onClear: () -> Void

    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore

    // Локальное состояние кол-ва — обновляется мгновенно, сеть идёт с дебаунсом
    @State private var localQtys: [String: Int] = [:]
    @State private var debounceWorks: [String: DispatchWorkItem] = [:]

    private func qty(for item: CartSummaryStoreItem) -> Int {
        localQtys[item.product.uuid] ?? item.quantity
    }

    private var localTotal: Double {
        summary.cheapestPerProduct.reduce(0) { acc, item in
            acc + item.price * Double(qty(for: item))
        }
    }

    private var totalItems: Int {
        summary.cheapestPerProduct.reduce(0) { acc, item in acc + qty(for: item) }
    }

    private func scheduleUpdate(uuid: String, newQty: Int) {
        debounceWorks[uuid]?.cancel()
        guard let cart = cartStore.cart else { return }
        let work = DispatchWorkItem {
            Task { await vm.updateQuantity(cart: cart, productUuid: uuid, quantity: newQty, cityId: cityStore.selectedCityId) }
        }
        debounceWorks[uuid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Кастомный заголовок страницы
                HStack {
                    BrandTitle(text: "Корзина")
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: onClear) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.discountRed)
                                .frame(width: 36, height: 36)
                                .background(Color.appCard, in: Circle())
                                .neumorphicButton()
                        }
                        if let uuid = cartUUID {
                            ShareLink(item: URL(string: "https://minprice.kz/cart/\(uuid)")!) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.appPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.appCard, in: Circle())
                                    .neumorphicButton()
                            }
                        }
                    }
                }

                // Шапка — итого (обновляется мгновенно)
                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ИТОГО ПО МИНИМУМУ")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                                .kerning(0.8)
                            Text("\(formattedPrice(localTotal)) ₸")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(Color.savingsGreen)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: localTotal)
                        }
                        Spacer()
                        Text("\(totalItems) \(itemsWord(totalItems))")
                            .font(.jb(13))
                            .foregroundStyle(Color.appMuted)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.15), value: totalItems)
                    }
                    .padding(16)
                }
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))

                // Список товаров
                VStack(alignment: .leading, spacing: 10) {
                    Text("Лучшие цены")
                        .font(.jb(15, weight: .semibold))
                        .foregroundStyle(Color.appForeground)

                    VStack(spacing: 0) {
                        ForEach(Array(summary.cheapestPerProduct.enumerated()), id: \.element.product.uuid) { idx, item in
                            CartItemRow(
                                item: item,
                                qty: qty(for: item),
                                onRemove: { onRemove(item.product.uuid) },
                                onQuantityChange: { newQty in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        localQtys[item.product.uuid] = newQty
                                    }
                                    scheduleUpdate(uuid: item.product.uuid, newQty: newQty)
                                }
                            )
                            if idx < summary.cheapestPerProduct.count - 1 {
                                Divider().overlay(Color.appBorder).padding(.leading, 82)
                            }
                        }
                    }
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
                }
                .onAppear {
                    for item in summary.cheapestPerProduct {
                        localQtys[item.product.uuid] = item.quantity
                    }
                }
                .onChange(of: summary.cart.updatedAt) { _ in
                    for item in summary.cheapestPerProduct {
                        let uuid = item.product.uuid
                        if debounceWorks[uuid] == nil {
                            localQtys[uuid] = item.quantity
                        }
                    }
                }

                // Сравнение по магазинам
                if !summary.singleStoreTotals.isEmpty {
                    StoreComparisonSection(totals: summary.singleStoreTotals, vm: vm)
                }

                // Недоступные товары
                if !summary.unavailableProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.appMuted)
                            Text("Нет в наличии")
                                .font(.jb(15, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                            Spacer()
                            Button {
                                guard let cart = cartStore.cart else { return }
                                let uuids = summary.unavailableProducts.map { $0.product.uuid }
                                Task {
                                    await vm.removeItems(cart: cart, productUuids: uuids, cityId: cityStore.selectedCityId)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Убрать всё")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Color.discountRed)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.discountRed.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(summary.unavailableProducts.enumerated()), id: \.element.product.uuid) { idx, item in
                                HStack(spacing: 12) {
                                    KFImage(item.product.coverURL)
                                        .downsampled(to: CGSize(width: 44, height: 44))
                                        .cancelOnDisappear(true)
                                        .resizable().scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .background(Color.appBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .opacity(0.6)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.product.title)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.appMuted)
                                            .lineLimit(2)
                                        Text(item.reason)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.discountRed.opacity(0.8))
                                    }
                                    Spacer()
                                    Button {
                                        onRemove(item.product.uuid)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color.discountRed)
                                            .frame(width: 36, height: 36)
                                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
                                            .neumorphicButton()
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        onRemove(item.product.uuid)
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }

                                if idx < summary.unavailableProducts.count - 1 {
                                    Divider().overlay(Color.appBorder).padding(.leading, 70)
                                }
                            }
                        }
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private func formattedPrice(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: val)) ?? "\(Int(val))"
    }

    private func itemsWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "товаров" }
        if m10 == 1 { return "товар" }
        if m10 >= 2 && m10 <= 4 { return "товара" }
        return "товаров"
    }
}

// MARK: - Cart item row

private struct CartItemRow: View {
    let item: CartSummaryStoreItem
    let qty: Int
    let onRemove: () -> Void
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            KFImage(item.product.coverURL)
                .placeholder { Rectangle().fill(Color.appBackground) }
                .downsampled(to: CGSize(width: 56, height: 56))
                .cancelOnDisappear(true)
                .resizable().scaledToFit()
                .frame(width: 56, height: 56)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    StoreLogoView(url: chainLogoURL(item.chainLogo), slug: item.chainSlug, source: item.chainSource, size: 14)
                    Text(item.chainName ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.appMuted)
                }
                Text("\(Int(item.price)) ₸ / шт")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(Int(item.price * Double(qty))) ₸")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.appForeground)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.12), value: qty)

                HStack(spacing: 4) {
                    Button {
                        if qty <= 1 { onRemove() }
                        else { onQuantityChange(qty - 1) }
                    } label: {
                        Image(systemName: qty <= 1 ? "trash" : "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(qty <= 1 ? Color.discountRed : Color.appPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
                            .neumorphicButton()
                    }
                    .buttonStyle(.plain)

                    Text("\(qty)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appForeground)
                        .frame(minWidth: 28)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.12), value: qty)

                    Button { onQuantityChange(qty + 1) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10))
                            .neumorphicButton()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

    // chainSource — старая фильтрация (mgo/arbuz/airbafresh имеют свой source).
    // Для Wolt-сетей (Small/Galmart/Toimart) кнопка-deeplink тоже должна быть.
    private let transferableSources: Set<String> = ["arbuz", "airbafresh", "mgo", "wolt"]
    private func canTransfer(_ store: SingleStoreTotal) -> Bool {
        transferableSources.contains(store.chainSource)
    }
    private var minPrice: Double { totals.map(\.totalPrice).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Если купить в одном магазине")
                .font(.jb(15, weight: .semibold))
                .foregroundStyle(Color.appForeground)

            VStack(spacing: 0) {
                ForEach(Array(totals.enumerated()), id: \.element.id) { idx, store in
                    let isCheapest = store.totalPrice == minPrice && store.availableCount == store.totalCount

                    HStack(spacing: 12) {
                        StoreLogoView(url: chainLogoURL(store.chainLogo), slug: store.chainSlug, source: store.chainSource, size: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(isCheapest ? Color.savingsGreen.opacity(0.7) : Color.clear, lineWidth: 2)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(store.chainName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.appForeground)
                                if isCheapest {
                                    Text("min")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Color.savingsGreen)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.savingsGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Text("\(store.availableCount) из \(store.totalCount) товаров")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.appMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(store.totalPrice)) ₸")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isCheapest ? Color.savingsGreen : Color.appForeground)
                            if store.availableCount < store.totalCount {
                                Text("не все товары")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.appMuted)
                            }
                        }

                        if canTransfer(store) {
                            Button {
                                Task {
                                    // Для Wolt-сетей различаем по slug — иначе deeplink уйдёт не туда
                                    let key = store.chainSlug ?? store.chainSource
                                    transferringSource = key
                                    if let url = await vm.transferToStore(
                                        chainSource: store.chainSource,
                                        chainSlug: store.chainSlug,
                                        items: store.products,
                                        cityId: cityStore.selectedCityId
                                    ) {
                                        await UIApplication.shared.open(url)
                                    }
                                    transferringSource = nil
                                }
                            } label: {
                                let key = store.chainSlug ?? store.chainSource
                                if transferringSource == key {
                                    ProgressView().tint(Color.appPrimary).frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(isCheapest ? Color.savingsGreen : Color.appPrimary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        if isCheapest {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.savingsGreen.opacity(0.10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.savingsGreen.opacity(0.3), lineWidth: 1))
                        }
                    }

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


// Резолвит chain_logo путь от бэка (относительный или абсолютный) в URL
private func chainLogoURL(_ raw: String?) -> URL? {
    guard let raw, !raw.isEmpty else { return nil }
    if raw.hasPrefix("http") { return URL(string: raw) }
    if raw.hasPrefix("/")    { return URL(string: "https://backend.minprice.kz\(raw)") }
    return URL(string: "https://backend.minprice.kz/media/\(raw)")
}
