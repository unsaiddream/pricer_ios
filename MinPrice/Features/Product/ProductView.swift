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

    var body: some View {
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .preference(key: HideBottomBarsKey.self, value: true)
        .onTapGesture(count: 2) {
            if let product = vm.product {
                let image = makeProductShareImage(product: product, productImage: loadedProductImage) ?? UIImage()
                let url = URL(string: "https://minprice.kz/products/\(product.uuid)/")
                shareItem = ShareImageItem(image: image, url: url)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ProductActionBar(
                added: addedToCart,
                favorited: favoritesStore.isFavorited(uuid),
                onBack: { dismiss() },
                onAddToCart: {
                    guard !addedToCart else { return }
                    Task {
                        do {
                            try await cartStore.quickAdd(productUuid: uuid)
                            withAnimation { addedToCart = true }
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation { addedToCart = false }
                        } catch {}
                    }
                },
                onFavorite: {
                    if let product = vm.product {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            favoritesStore.toggle(product)
                        }
                    }
                },
                onShare: {
                    if let product = vm.product {
                        let image = makeProductShareImage(product: product, productImage: loadedProductImage) ?? UIImage()
                        let url = URL(string: "https://minprice.kz/products/\(product.uuid)/")
                        shareItem = ShareImageItem(image: image, url: url)
                    }
                }
            )
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
}

// MARK: - Product Action Bar (bottom)

private struct ProductActionBar: View {
    let added: Bool
    let favorited: Bool
    let onBack: () -> Void
    let onAddToCart: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Назад
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appForeground)
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // В корзину
            Button(action: onAddToCart) {
                HStack(spacing: 6) {
                    Image(systemName: added ? "checkmark.circle.fill" : "cart.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text(added ? "Добавлено!" : "В корзину")
                        .font(.jb(14, weight: .semibold))
                }
                .foregroundStyle(added ? .white : Color.appPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    added ? Color.green : Color.appPrimary.opacity(0.22),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(
                    added ? Color.clear : Color.appPrimary.opacity(0.5),
                    lineWidth: 1
                ))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: added)

            // Поделиться (на уровне корзины), звёздочка — overlay сверху
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.appForeground)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                    }
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                Button(action: onFavorite) {
                    Image(systemName: favorited ? "star.fill" : "star")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(favorited ? Color.appPrimary : Color.appForeground)
                        .frame(width: 46, height: 30)
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(favorited ? Color.appPrimary.opacity(0.12) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(favorited ? Color.appPrimary.opacity(0.45) : Color.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: favorited)
                .offset(y: -36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .padding(.top, 8)
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
                        .background(Color.savingsGreen.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.savingsGreen.opacity(0.4), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    .background(isBest ? Color.savingsGreen.opacity(0.06) : Color.clear)
                    .overlay(
                        isBest ? RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.savingsGreen.opacity(0.4), lineWidth: 1) : nil
                    )
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

