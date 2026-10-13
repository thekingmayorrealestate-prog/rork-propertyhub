import SwiftUI

struct CategoryListView: View {
    let category: ListingCategory

    @Environment(AppStore.self) private var store
    @State private var sort: SortOption = .recommended
    @State private var type: PropertyType?

    private var listings: [Listing] {
        var filters = SearchFilters()
        filters.category = category
        filters.sort = sort
        if let type { filters.types = [type] }
        return store.search(filters)
    }

    private var availableTypes: [PropertyType] {
        let used = Set(store.liveListings(in: category).map(\.propertyType))
        return PropertyType.allCases.filter { used.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Color.clear
                    .frame(height: 150)
                    .overlay { ListingPhoto(name: category.heroImage) }
                    .overlay { Color.black.opacity(0.32) }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(category.title, systemImage: category.symbol)
                                .font(.subheadline.weight(.semibold))
                            Text("\(listings.count) available")
                                .font(.title2.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                    }
                    .clipShape(.rect(cornerRadius: Theme.cardRadius))
                    .padding(.horizontal, 16)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        chip("All", selected: type == nil) { type = nil }
                        ForEach(availableTypes) { t in
                            chip(t.title, selected: type == t) { type = t }
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)

                LazyVStack(spacing: 12) {
                    ForEach(listings) { listing in
                        NavigationLink(value: Route.listing(listing.id)) {
                            ListingRow(listing: listing)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 16)

                if listings.isEmpty {
                    ContentUnavailableView("No listings yet", systemImage: "house", description: Text("Check back soon — new homes are approved daily."))
                        .padding(.top, 40)
                }
            }
            .padding(.vertical, 12)
        }
        .screenBackground()
        .navigationTitle(category.pluralTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(SortOption.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? .white : Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(selected ? Theme.primary : Theme.surface, in: .capsule)
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}
