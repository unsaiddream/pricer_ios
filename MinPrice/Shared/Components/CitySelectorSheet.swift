import SwiftUI

struct CitySelectorSheet: View {
    @EnvironmentObject var cityStore: CityStore
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(cityStore.cities) { city in
                    Button {
                        cityStore.selectedCityId = city.id
                        isPresented = false
                    } label: {
                        HStack {
                            Text(city.name)
                                .font(.jb(15))
                                .foregroundStyle(Color.appForeground)
                            Spacer()
                            if city.id == cityStore.selectedCityId {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                    .listRowBackground(Color.appCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Выберите город")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") { isPresented = false }
                        .font(.jb(14))
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await cityStore.loadCities() }
    }
}
