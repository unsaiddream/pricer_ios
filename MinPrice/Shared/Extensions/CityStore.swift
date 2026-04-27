import SwiftUI

final class CityStore: ObservableObject {
    @AppStorage("minprice_city_id") var selectedCityId: Int = 1
    @Published var cities: [City] = []
    @Published var isLoading = false

    var selectedCity: City? {
        cities.first { $0.id == selectedCityId }
    }

    var cityQueryItem: URLQueryItem {
        URLQueryItem(name: "city_id", value: String(selectedCityId))
    }

    @MainActor
    func loadCities() async {
        guard cities.isEmpty else { return }
        isLoading = true
        do {
            let response = try await APIClient.shared.fetch(CitiesResponse.self, path: Endpoint.cities())
            cities = response.cities
            Log.debug("🏙️ cities: \(cities.map { "\($0.id)=\($0.name)" })")
            // Auto-select first city if current selection is invalid
            if !cities.isEmpty && cities.first(where: { $0.id == selectedCityId }) == nil {
                selectedCityId = cities[0].id
                Log.debug("🏙️ auto-selected city: \(cities[0].name) id=\(cities[0].id)")
            }
        } catch {}
        isLoading = false
    }
}
