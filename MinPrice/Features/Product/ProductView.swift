import SwiftUI
import Charts
import Kingfisher

struct ProductView: View {
    let uuid: String

    @EnvironmentObject var cityStore: CityStore
    @EnvironmentObject var cartStore: CartStore
    @EnvironmentObject var favoritesStore: FavoritesStore
    @StateObject private var vm = ProductViewModel()
    @State private var addedToCart = false
    @State private var shareItem: ShareImageItem? = nil
    @State private var loadedProductImage: UIImage? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var showRadialMenu = false
    @State private var radialMenuAppeared = false
    @State private var radialMenuCenter: CGPoint = .zero
    @State private var pressTimer: Timer? = nil
    @State private var hoveredAction: RadialAction? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ScrollView {
                    if vm.isLoading {
                        SkeletonProductDetail()
                    } else if let product = vm.product {
                        VStack(alignment: .leading, spacing: 0) {

                            KFImage(product.coverURL)
                                .placeholder { Rectangle().fill(Color.appBackground) }
                                .onSuccess { result in loadedProductImage = result.image }
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: 260)
                                .background(Color.appBackground)

                            VStack(alignment: .leading, spacing: 16) {

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.title)
                                        .font(.jb(18, weight: .bold))
                                        .foregroundStyle(Color.appForeground)
                                    if let brand = product.brand {
                                        Text(brand)
                                            .font(.jb(14))
                                            .foregroundStyle(Color.appMuted)
                                    }
                                }

                                if let range = product.priceRange {
                                    PriceRangeBanner(range: range)
                                }

                                if let stores = product.priceRange?.stores, !stores.isEmpty {
                                    StorePricesSection(stores: stores)
                                }

                                if let history = vm.priceHistory, !history.stores.isEmpty {
                                    PriceHistoryChart(history: history)
                                }

                                if let desc = product.description, !desc.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Описание")
                                            .font(.jb(15, weight: .semibold))
                                            .foregroundStyle(Color.appForeground)
                                        Text(desc)
                                            .font(.jb(14))
                                            .foregroundStyle(Color.appMuted)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .background(Color.appBackground)
                .overlay(alignment: .top) {
                    HStack {
                        NavGlassButton(icon: "chevron.left") { dismiss() }
                        Spacer()
                        NavGlassButton(icon: "square.and.arrow.up") {
                            if let product = vm.product {
                                let image = makeProductShareImage(product: product, productImage: loadedProductImage) ?? UIImage()
                                let url = URL(string: "https://minprice.kz/products/\(product.uuid)/")
                                shareItem = ShareImageItem(image: image, url: url)
                            }
                        }
                        NavGlassButton(
                            icon: favoritesStore.isFavorited(uuid) ? "star.fill" : "star",
                            tint: favoritesStore.isFavorited(uuid) ? Color.appPrimary : Color.appForeground
                        ) {
                            if let product = vm.product {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    favoritesStore.toggle(product)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .opacity(showRadialMenu ? 0 : 1)
                    .animation(.easeInOut(duration: 0.15), value: showRadialMenu)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if showRadialMenu {
                                updateHover(at: value.location, safeAreaTop: geo.safeAreaInsets.top)
                            } else {
                                guard pressTimer == nil else { return }
                                let loc = value.location
                                let timer = Timer(timeInterval: 0.45, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        radialMenuCenter = loc
                                        showRadialMenu = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
                                                radialMenuAppeared = true
                                            }
                                        }
                                        pressTimer = nil
                                    }
                                }
                                RunLoop.main.add(timer, forMode: .common)
                                pressTimer = timer
                            }
                        }
                        .onEnded { _ in
                            pressTimer?.invalidate()
                            pressTimer = nil
                            if showRadialMenu {
                                executeHoveredAction()
                                dismissRadialMenu()
                                hoveredAction = nil
                            }
                        }
                )

                if showRadialMenu {
                    RadialMenuOverlay(
                        center: radialMenuCenter,
                        appeared: radialMenuAppeared,
                        safeAreaTop: geo.safeAreaInsets.top,
                        screenWidth: geo.size.width,
                        isFavorited: favoritesStore.isFavorited(uuid),
                        hoveredAction: hoveredAction
                    )
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preference(key: HideBottomBarsKey.self, value: true)
        .safeAreaInset(edge: .bottom) {
            ProductCartBar(added: addedToCart) {
                guard !addedToCart else { return }
                Task {
                    do {
                        try await cartStore.quickAdd(productUuid: uuid)
                        withAnimation { addedToCart = true }
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation { addedToCart = false }
                    } catch {}
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ProductSharePreviewSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await vm.load(uuid: uuid, cityId: cityStore.selectedCityId)
        }
    }

    private func dismissRadialMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            radialMenuAppeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRadialMenu = false
        }
    }

    private func radialTarget(deg: Double) -> CGPoint {
        let radius: CGFloat = 84
        let rad = deg * .pi / 180
        return CGPoint(x: radialMenuCenter.x + radius * CGFloat(cos(rad)),
                       y: radialMenuCenter.y + radius * CGFloat(sin(rad)))
    }

    private func updateHover(at location: CGPoint, safeAreaTop: CGFloat) {
        let threshold: CGFloat = 50
        let items: [(RadialAction, Double)] = [(.back, 220), (.share, 270), (.favorite, 320)]
        for (action, deg) in items {
            let t = radialTarget(deg: deg)
            if hypot(t.x - location.x, t.y - location.y) < threshold {
                if hoveredAction != action {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    hoveredAction = action
                }
                return
            }
        }
        hoveredAction = nil
    }

    private func executeHoveredAction() {
        switch hoveredAction {
        case .back:
            dismiss()
        case .share:
            if let p = vm.product {
                let img = makeProductShareImage(product: p, productImage: loadedProductImage) ?? UIImage()
                shareItem = ShareImageItem(image: img, url: URL(string: "https://minprice.kz/products/\(p.uuid)/"))
            }
        case .favorite:
            if let p = vm.product {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { favoritesStore.toggle(p) }
            }
        case nil:
            break
        }
    }
}

// MARK: - Nav Glass Button

private struct NavGlassButton: View {
    let icon: String
    var tint: Color = Color.appForeground
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle().fill(LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Radial Action

private enum RadialAction: Equatable { case back, share, favorite }

// MARK: - Radial Menu Overlay

private struct RadialMenuOverlay: View {
    let center: CGPoint
    let appeared: Bool
    let safeAreaTop: CGFloat
    let screenWidth: CGFloat
    let isFavorited: Bool
    let hoveredAction: RadialAction?

    private let radius: CGFloat = 84

    private var backSource: CGPoint { CGPoint(x: 35, y: safeAreaTop + 27) }
    private var shareSource: CGPoint { CGPoint(x: screenWidth - 81, y: safeAreaTop + 27) }
    private var favSource: CGPoint { CGPoint(x: screenWidth - 35, y: safeAreaTop + 27) }

    private func radialPos(deg: Double) -> CGPoint {
        let rad = deg * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(rad)),
                       y: center.y + radius * CGFloat(sin(rad)))
    }

    var body: some View {
        ZStack {
            flyButton("chevron.left", Color.appForeground,
                      from: backSource, to: radialPos(deg: 220),
                      delay: 0.00, hovered: hoveredAction == .back)
            flyButton("square.and.arrow.up", Color.appForeground,
                      from: shareSource, to: radialPos(deg: 270),
                      delay: 0.04, hovered: hoveredAction == .share)
            flyButton(isFavorited ? "star.fill" : "star",
                      isFavorited ? Color.appPrimary : Color.appForeground,
                      from: favSource, to: radialPos(deg: 320),
                      delay: 0.08, hovered: hoveredAction == .favorite)
        }
    }

    @ViewBuilder
    private func flyButton(_ icon: String, _ tint: Color,
                           from source: CGPoint, to target: CGPoint,
                           delay: Double, hovered: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(hovered ? Color.white : tint)
            .frame(width: 46, height: 46)
            .background(
                hovered ? AnyShapeStyle(Color.appPrimary) : AnyShapeStyle(Material.ultraThin),
                in: Circle()
            )
            .overlay {
                Circle().fill(LinearGradient(
                    colors: [Color.white.opacity(hovered ? 0.3 : 0.18), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            .overlay(Circle().stroke(Color.white.opacity(hovered ? 0.6 : 0.3), lineWidth: hovered ? 1 : 0.5))
            .shadow(color: .black.opacity(hovered ? 0.35 : 0.28), radius: hovered ? 18 : 14, x: 0, y: 5)
            .scaleEffect(appeared ? (hovered ? 1.18 : 1.0) : 0.55)
            .position(appeared ? target : source)
            .animation(.spring(response: 0.48, dampingFraction: 0.68).delay(appeared ? delay : 0), value: appeared)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hovered)
    }
}

// MARK: - Product Cart Bar (floating liquid glass)

private struct ProductCartBar: View {
    let added: Bool
    let onAddToCart: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onAddToCart) {
                HStack(spacing: 8) {
                    Image(systemName: added ? "checkmark.circle.fill" : "cart.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(added ? Color.green : Color.appForeground)
                    Text(added ? "Добавлено" : "В корзину")
                        .font(.jb(15, weight: .semibold))
                        .foregroundStyle(added ? Color.green : Color.appForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                }
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: added)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .padding(.top, 4)
    }
}

// MARK: - Subviews

private struct PriceRangeBanner: View {
    let range: PriceRange

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("от \(Int(range.min)) ₸")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.savingsGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 8).fill(Color.savingsGreen.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.savingsGreen.opacity(0.35), lineWidth: 1))
                        }
                    Text("до \(Int(range.max)) ₸")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appMuted)
                }
                Text("среднее \(Int(range.avg)) ₸")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
            if let savings = range.savingsPercent, savings > 1 {
                Text("−\(Int(savings))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.discountRed, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
    }
}

private struct StorePricesSection: View {
    let stores: [PriceRangeStore]
    private var minPrice: Double { stores.map(\.price).min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цены в магазинах")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appForeground)

            VStack(spacing: 0) {
                ForEach(Array(stores.enumerated()), id: \.element.storeName) { idx, store in
                    let isBest = store.price == minPrice

                    HStack(spacing: 10) {
                        StoreLogoView(url: store.logoURL, source: store.storeSource, size: 30)

                        Text(store.chainName)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appForeground)

                        if isBest {
                            Text("мин")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.savingsGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.savingsGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(store.price)) ₸")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isBest ? Color.savingsGreen : Color.appForeground)
                            if let prev = store.previousPrice, prev > store.price {
                                Text("\(Int(prev)) ₸")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.appMuted)
                                    .strikethrough()
                            }
                        }

                        if let urlStr = store.url, let url = URL(string: urlStr) {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(isBest ? Color.savingsGreen : Color.appPrimary)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background {
                        if isBest {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 10).fill(Color.savingsGreen.opacity(0.07)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.savingsGreen.opacity(0.35), lineWidth: 1))
                        }
                    }
                    .opacity(store.inStock ? 1 : 0.5)

                    if idx < stores.count - 1 {
                        Divider().overlay(Color.appBorder)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        }
    }
}

private struct PriceHistoryChart: View {
    let history: PriceHistoryResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("История цен")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appForeground)

            Chart {
                ForEach(history.stores) { store in
                    ForEach(store.prices) { point in
                        if let date = point.parsedDate {
                            LineMark(
                                x: .value("Дата", date),
                                y: .value("Цена", point.price)
                            )
                            .foregroundStyle(by: .value("Магазин", store.storeName))
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(14)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1))
        }
    }
}

// MARK: - Share helpers

// MARK: - Share Preview Sheet

struct ProductSharePreviewSheet: View {
    let item: ShareImageItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
            }

            Divider().padding(.top, 8)

            Button {
                let vc = UIActivityViewController(activityItems: item.activityItems, applicationActivities: nil)
                vc.completionWithItemsHandler = { type, _, _, _ in if type != nil { dismiss() } }
                guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let root = scene.windows.first?.rootViewController else { return }
                var top = root
                while let p = top.presentedViewController { top = p }
                top.present(vc, animated: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Поделиться")
                        .font(.jb(15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .padding(.bottom, 8)
        }
    }
}


struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let url: URL?

    var activityItems: [Any] {
        var items: [Any] = [image]
        if let url {
            items.append("Нашёл выгодное предложение на minprice.kz\n\(url.absoluteString)")
        }
        return items
    }
}

