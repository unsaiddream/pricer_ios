import SwiftUI

@main
struct MinPriceApp: App {
    @StateObject private var cityStore = CityStore()
    @StateObject private var cartStore = CartStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @AppStorage("isDarkMode") private var isDarkMode = false

    init() {
        applyGlobalFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cityStore)
                .environmentObject(cartStore)
                .environmentObject(favoritesStore)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .task {
                    await APIClient.shared.initSession()
                    await cityStore.loadCities()
                    await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
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
