import SwiftUI

@main
struct MinPriceApp: App {
    @StateObject private var cityStore = CityStore()
    @StateObject private var cartStore = CartStore()
    @StateObject private var favoritesStore = FavoritesStore()
    @State private var isReady = false

    init() {
        applyGlobalFonts()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isReady {
                    ContentView()
                        .environmentObject(cityStore)
                        .environmentObject(cartStore)
                        .environmentObject(favoritesStore)
                        .transition(.opacity)
                }
                if !isReady {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.light)
            .task {
                await APIClient.shared.initSession()
                await cityStore.loadCities()
                await cartStore.loadActiveCart(cityId: cityStore.selectedCityId)
                withAnimation(.easeInOut(duration: 0.5)) {
                    isReady = true
                }
            }
        }
    }

    private func applyGlobalFonts() {
        let medium   = UIFont(name: "JetBrainsMono-Medium", size: 17) ?? .systemFont(ofSize: 17)
        let semibold = UIFont(name: "JetBrainsMono-SemiBold", size: 17) ?? .boldSystemFont(ofSize: 17)

        // NavigationBar title
        UINavigationBar.appearance().titleTextAttributes = [
            .font: medium
        ]
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .font: UIFont(name: "JetBrainsMono-Bold", size: 32) ?? .boldSystemFont(ofSize: 32)
        ]

        // TabBar labels
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "JetBrainsMono-Medium", size: 10) ?? .systemFont(ofSize: 10)],
            for: .normal
        )
        UITabBarItem.appearance().setTitleTextAttributes(
            [.font: UIFont(name: "JetBrainsMono-Medium", size: 10) ?? .systemFont(ofSize: 10)],
            for: .selected
        )

        // Search bar
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).font =
            UIFont(name: "JetBrainsMono-Regular", size: 16)

        _ = semibold // подавляем warning
    }
}
