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
                } else if let summary = vm.summary, summary.hasVisibleItems {
                    CartSummaryView(
                        summary: summary,
                        vm: vm,
                        onRemove: { productUuid in
                            guard let cart = cartStore.cart else { return }
                            Task {
                                if let summary = await vm.removeItem(cart: cart, productUuid: productUuid, cityId: cityStore.selectedCityId) {
                                    cartStore.apply(summary: summary)
                                }
                            }
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
                    Task {
                        if let summary = await vm.clearCart(cart: cart, cityId: cityStore.selectedCityId) {
                            cartStore.apply(summary: summary)
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все товары будут удалены из корзины")
            }
        }
        .refreshable {
            await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
            if let summary = await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) {
                cartStore.apply(summary: summary)
            }
        }
        .task {
            await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
            if let summary = await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) {
                cartStore.apply(summary: summary)
            }
        }
        .onChange(of: cartStore.cart?.uuid) { _ in
            // Fires when cart UUID changes (new cart created)
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
        .onChange(of: cartStore.refreshCount) { _ in
            // Fires after quickAdd — reload summary to show new item
            Task { await vm.load(cart: cartStore.cart, cityId: cityStore.selectedCityId) }
        }
    }
}

// MARK: - Empty state

private struct EmptyCartView: View {
    var body: some View {
        VStack(spacing: 20) {
            ErrorStateView(
                .empty(
                    title: "Корзина пуста",
                    message: "Добавляйте товары из поиска или каталога",
                    systemImage: "cart"
                )
            )
            .frame(maxHeight: 260)
            Button {
                NotificationCenter.default.post(name: .switchTab, object: Tab.catalog)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Перейти в каталог")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(LinearGradient.brandPrimary, in: Capsule())
                .shadow(color: Color.appPrimary.opacity(0.30), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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
    let onClear: () -> Void

    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore

    // Локальное состояние кол-ва — обновляется мгновенно, сеть идёт с дебаунсом
    @State private var localQtys: [String: Int] = [:]
    @State private var debounceWorks: [String: DispatchWorkItem] = [:]

    // Режим отображения: "mix" — корзина по минимуму (по магазинам разбито),
    // "single" — сравнение что выйдет если купить ВСЁ в одном магазине.
    // Хранится в @AppStorage чтобы пользователю не приходилось выбирать каждый раз.
    @AppStorage("cart_view_mode") private var viewMode: String = "mix"

    private func qty(for item: CartSummaryStoreItem) -> Int {
        localQtys[item.product.uuid] ?? item.quantity
    }

    private var localTotal: Double {
        summary.cheapestPerProduct.reduce(0) { acc, item in
            acc + item.price * Double(qty(for: item))
        }
    }

    private func localTotal(replacing productUuid: String, with quantity: Int) -> Double {
        summary.cheapestPerProduct.reduce(0) { acc, item in
            let itemQuantity = item.product.uuid == productUuid ? quantity : qty(for: item)
            return acc + item.price * Double(itemQuantity)
        }
    }

    private var totalItems: Int {
        let available = summary.cheapestPerProduct.reduce(0) { acc, item in acc + qty(for: item) }
        let unavailable = summary.unavailableProducts.reduce(0) { acc, item in
            acc + (localQtys[item.product.uuid] ?? item.quantity)
        }
        return available + unavailable
    }

    private var quantityByProduct: [String: Int] {
        var quantities: [String: Int] = [:]
        for item in summary.cheapestPerProduct {
            quantities[item.product.uuid] = qty(for: item)
        }
        for item in summary.unavailableProducts where quantities[item.product.uuid] == nil {
            quantities[item.product.uuid] = localQtys[item.product.uuid] ?? item.quantity
        }
        return quantities
    }

    private func singleStoreTotal(for store: SingleStoreTotal) -> Double {
        guard !store.products.isEmpty else { return store.totalPrice }
        return store.products.reduce(0) { total, item in
            let quantity = quantityByProduct[item.product.uuid] ?? item.quantity
            return total + item.price * Double(quantity)
        }
    }

    /// Самая дорогая «один магазин» цена — нужна как baseline для подсчёта savings.
    /// Если у пользователя в корзине только товары одного магазина — savings нулевая.
    private var worstSingleStorePrice: Double? {
        guard !summary.singleStoreTotals.isEmpty else { return nil }
        // Считаем только магазины где доступны все товары — иначе сравнение нечестное.
        let complete = summary.singleStoreTotals.filter { $0.availableCount == $0.totalCount }
        return complete.map(singleStoreTotal).max() ?? summary.singleStoreTotals.map(singleStoreTotal).max()
    }

    private var savingsAmount: Double {
        guard let worst = worstSingleStorePrice, worst > localTotal else { return 0 }
        return worst - localTotal
    }

    private var shareURL: URL? {
        URL(string: "https://minprice.kz/cart/\(summary.cart.uuid)/")
    }

    private func scheduleUpdate(uuid: String, newQty: Int) {
        let previousQty = localQtys[uuid] ?? summary.cheapestPerProduct.first(where: { $0.product.uuid == uuid })?.quantity
        debounceWorks[uuid]?.cancel()
        guard let cart = cartStore.cart else { return }
        let work = DispatchWorkItem {
            Task {
                let summary = await vm.updateQuantity(cart: cart, productUuid: uuid, quantity: newQty, cityId: cityStore.selectedCityId)
                debounceWorks[uuid] = nil
                if let summary {
                    cartStore.apply(summary: summary, quantityOverrides: [uuid: newQty])
                } else if let previousQty {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        localQtys[uuid] = previousQty
                    }
                    cartStore.applyLocalQuantity(
                        productUuid: uuid,
                        quantity: previousQty,
                        totalOverride: localTotal(replacing: uuid, with: previousQty)
                    )
                }
            }
        }
        debounceWorks[uuid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Кастомный заголовок страницы
                HStack {
                    BrandTitle(text: "Корзина",
                               eyebrow: "Экономия в реальном времени",
                               accent: Color.savingsGreen)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: onClear) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.discountRed)
                                .frame(width: 36, height: 36)
                                .background(Color.appCard, in: Circle())
                                .overlay(Circle().stroke(Color.appBorder, lineWidth: 1))
                        }
                        if let shareURL {
                            ShareLink(item: shareURL) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.appPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.appCard, in: Circle())
                                    .overlay(Circle().stroke(Color.appBorder, lineWidth: 1))
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                CrashReporter.action("cart_share_tap")
                            })
                        }
                    }
                }

                // Шапка — итого (обновляется мгновенно)
                VStack(spacing: 10) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ИТОГО ПО МИНИМУМУ")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.appMuted)
                                .kerning(0.8)
                            Text(formatPriceTg(localTotal))
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(Color.savingsGreen)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: localTotal)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(totalItems) \(itemsWord(totalItems))")
                                .font(.jb(13))
                                .foregroundStyle(Color.appMuted)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: totalItems)
                            if savingsAmount > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.right")
                                        .font(.system(size: 9, weight: .black))
                                    Text("экономия \(formatPriceTg(savingsAmount))")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Color.savingsGreen)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.savingsGreen.opacity(0.12), in: Capsule())
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // Mode toggle — как на сайте: "Микс" или "Один магазин"
                    if !summary.singleStoreTotals.isEmpty {
                        ModeToggle(viewMode: $viewMode)
                    }
                }
                .padding(16)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))

                // Список товаров — показываем только в режиме "Микс"
                if viewMode == "mix" || summary.singleStoreTotals.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        AppSectionHeader(
                            title: "Лучшие цены",
                            subtitle: "Собрано по минимуму",
                            icon: "sparkles",
                            accent: Color.savingsGreen
                        )

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
                                        cartStore.applyLocalQuantity(
                                            productUuid: item.product.uuid,
                                            quantity: newQty,
                                            totalOverride: localTotal(replacing: item.product.uuid, with: newQty)
                                        )
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
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                // Сравнение по магазинам — всегда видно (это сердце фичи минимальных цен)
                if !summary.singleStoreTotals.isEmpty {
                    StoreComparisonSection(
                        totals: summary.singleStoreTotals,
                        quantityByProduct: quantityByProduct,
                        vm: vm
                    )
                }

                // Недоступные товары
                if !summary.unavailableProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            AppSectionHeader(
                                title: "Нет в наличии",
                                subtitle: "\(summary.unavailableProducts.count) товаров",
                                icon: "exclamationmark.circle",
                                accent: Color.warningAmber
                            )
                            Spacer()
                            Button {
                                guard let cart = cartStore.cart else { return }
                                let uuids = summary.unavailableProducts.map { $0.product.uuid }
                                Task {
                                    if let summary = await vm.removeItems(cart: cart, productUuids: uuids, cityId: cityStore.selectedCityId) {
                                        cartStore.apply(summary: summary)
                                    }
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
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 1))
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
            .padding(.bottom, 180)
        }
        .onAppear {
            for item in summary.cheapestPerProduct {
                localQtys[item.product.uuid] = item.quantity
            }
        }
        .onChange(of: summary.cart.updatedAt) { _ in
            for item in summary.cheapestPerProduct {
                let uuid = item.product.uuid
                let localQty = localQtys[uuid]
                if debounceWorks[uuid] == nil && (localQty == nil || localQty == item.quantity) {
                    localQtys[uuid] = item.quantity
                }
            }
        }
    }

    private func itemsWord(_ n: Int) -> String {
        let m10 = n % 10, m100 = n % 100
        if m100 >= 11 && m100 <= 19 { return "товаров" }
        if m10 == 1 { return "товар" }
        if m10 >= 2 && m10 <= 4 { return "товара" }
        return "товаров"
    }
}

// MARK: - Mode toggle (Микс vs Один магазин)

private struct ModeToggle: View {
    @Binding var viewMode: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach([("mix", "По минимуму", "sparkles"), ("single", "Один магазин", "storefront")], id: \.0) { key, title, icon in
                let isActive = viewMode == key
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        viewMode = key
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isActive ? .white : Color.appMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isActive {
                            Capsule()
                                .fill(LinearGradient.brandPrimary)
                                .matchedGeometryEffect(id: "mode_pill", in: ns)
                                .shadow(color: Color.appPrimary.opacity(0.30), radius: 6, x: 0, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.appBackground, in: Capsule())
        .overlay(Capsule().stroke(Color.appBorder, lineWidth: 0.5))
    }

    @Namespace private var ns
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
                Text("\(formatPriceTg(item.price)) / шт")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.appMuted.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(formatPriceTg(item.price * Double(qty)))
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
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 1))
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
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appBorder, lineWidth: 1))
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
    let quantityByProduct: [String: Int]
    let vm: CartViewModel

    @EnvironmentObject var cityStore: CityStore
    @State private var transferringSource: String? = nil

    // chainSource — старая фильтрация (mgo/arbuz/airbafresh имеют свой source).
    // Для Wolt-сетей (Small/Galmart/Toimart) кнопка-deeplink тоже должна быть.
    private let transferableSources: Set<String> = ["arbuz", "airbafresh", "mgo", "wolt"]
    private func canTransfer(_ store: SingleStoreTotal) -> Bool {
        guard ConfigSnapshot.isEnabled(.cartTransfer, default: false) else { return false }
        return transferableSources.contains(store.chainSource)
    }
    private func displayedTotal(for store: SingleStoreTotal) -> Double {
        guard !store.products.isEmpty else { return store.totalPrice }
        return store.products.reduce(0) { total, item in
            let quantity = quantityByProduct[item.product.uuid] ?? item.quantity
            return total + item.price * Double(quantity)
        }
    }

    private var minPrice: Double {
        let complete = totals.filter { $0.availableCount == $0.totalCount }
        let comparable = complete.isEmpty ? totals : complete
        return comparable.map(displayedTotal).min() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionHeader(
                title: "Один магазин",
                subtitle: "Сравнение полной корзины",
                icon: "storefront.fill",
                accent: Color.appPrimary
            )

            VStack(spacing: 0) {
                ForEach(Array(totals.enumerated()), id: \.element.id) { idx, store in
                    let totalPrice = displayedTotal(for: store)
                    let isCheapest = totalPrice == minPrice && store.availableCount == store.totalCount

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
                            Text(formatPriceTg(totalPrice))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(isCheapest ? Color.savingsGreen : Color.appForeground)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.15), value: totalPrice)
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
