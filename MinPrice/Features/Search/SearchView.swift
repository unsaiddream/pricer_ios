import SwiftUI
import PhotosUI

struct SearchView: View {
    @EnvironmentObject var cityStore: CityStore
    @StateObject private var vm = SearchViewModel()
    @State private var showImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Group {
                if vm.results.isEmpty && vm.query.isEmpty {
                    SearchEmptyState()
                } else {
                    List {
                        ForEach(vm.results) { product in
                            NavigationLink(value: product.uuid) {
                                ProductRow(product: product)
                            }
                            .listRowBackground(Color.appCard)
                            .onAppear {
                                if product.uuid == vm.results.last?.uuid {
                                    Task { await vm.loadMore(cityId: cityStore.selectedCityId) }
                                }
                            }
                        }

                        if vm.isLoading && vm.results.isEmpty {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonProductRow()
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.appBackground)
                            }
                        } else if vm.isLoading {
                            HStack { Spacer(); ProgressView().tint(Color.appPrimary); Spacer() }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.appBackground)
                        }

                        if vm.results.isEmpty && !vm.query.isEmpty && !vm.isLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundStyle(Color.appMuted)
                                    Text("По запросу «\(vm.query)»\nничего не найдено")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appMuted)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.vertical, 40)
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.appBackground)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Поиск")
            .navigationDestination(for: String.self) { uuid in
                ProductView(uuid: uuid)
            }
            .searchable(text: $vm.query, prompt: "Молоко, хлеб, сыр...")
            .onChange(of: vm.query) { _ in
                Task { await vm.search(cityId: cityStore.selectedCityId) }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .onChange(of: selectedPhoto) { item in
                guard item != nil else { return }
                vm.query = "поиск по фото"
                selectedPhoto = nil
            }
        }
    }
}

private struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.jb(48))
                .foregroundStyle(Color.appPrimary.opacity(0.4))
            Text("Найдите самые низкие цены")
                .font(.jb(16, weight: .semibold))
                .foregroundStyle(Color.appForeground)
            Text("Ищите товары по названию или бренду")
                .font(.jb(14))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
