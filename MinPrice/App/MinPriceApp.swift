import SwiftUI
import Kingfisher

@main
struct MinPriceApp: App {
    @StateObject private var cityStore = CityStore()
    @StateObject private var cartStore = CartStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        applyGlobalFonts()
        configureImageCache()
        PriceAlertManager.shared.registerBGTask()
    }

    // Лимиты для Kingfisher — без них на длинных скроллах память растёт пока OS
    // не начнёт выгружать кэш и выкидывать резкие GC-стуттеры.
    private func configureImageCache() {
        let cache = ImageCache.default
        // Память — 80MB (хватает на ~400 даунсемпленных карточек)
        cache.memoryStorage.config.totalCostLimit = 80 * 1024 * 1024
        cache.memoryStorage.config.countLimit = 250
        cache.memoryStorage.config.expiration = .seconds(600)
        // Диск — 200MB, неделя жизни
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(7)

        // Тайм-аут запросов — чтобы зависшие картинки не блокировали загрузчик
        let downloader = ImageDownloader.default
        downloader.downloadTimeout = 12
    }

    var body: some Scene {
        WindowGroup {
            LaunchGate()
                .environmentObject(cityStore)
                .environmentObject(cartStore)
                .environmentObject(favoritesStore)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .task {
                    // Сессия — критическая (даёт guest-uuid). Стартует первой.
                    // Cities и cart — параллельно после неё; cart использует дефолтный
                    // selectedCityId который доступен сразу из @AppStorage CityStore.
                    await APIClient.shared.initSession()
                    async let cities: () = cityStore.loadCities()
                    async let cart: () = cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
                    _ = await (cities, cart)
                }
                .onOpenURL { url in
                    // minprice://product/UUID
                    guard url.scheme == "minprice" else { return }
                    if url.host == "product", let uuid = url.pathComponents.dropFirst().first {
                        NotificationCenter.default.post(name: .priceAlertOpen, object: uuid)
                    }
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                PriceAlertManager.shared.scheduleBGTask()
                Task {
                    await PriceAlertManager.shared.checkIfNeeded(
                        favorites: favoritesStore.favorites,
                        cityId: cityStore.selectedCityId
                    )
                }
            }
        }
    }

    private func applyGlobalFonts() {
        let medium   = UIFont(name: "JetBrainsMono-Medium", size: 17) ?? .systemFont(ofSize: 17)
        let semibold = UIFont(name: "JetBrainsMono-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)

        UINavigationBar.appearance().titleTextAttributes = [.font: medium]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont(name: "JetBrainsMono-Bold", size: 32) ?? .boldSystemFont(ofSize: 32)
        ]
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "JetBrainsMono-Medium", size: 10) ?? .systemFont(ofSize: 10)],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "JetBrainsMono-Medium", size: 10) ?? .systemFont(ofSize: 10)],
            for: .selected
        )
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font =
            UIFont(name: "JetBrainsMono-Regular", size: 16)
        _ = semibold
    }
}
