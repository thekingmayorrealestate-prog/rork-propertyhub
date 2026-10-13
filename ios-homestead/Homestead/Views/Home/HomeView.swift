import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showFilters = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                categoryTiles
                featuredSection
                hotelSection
                shortletSection
                saleSection
            }
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showFilters) {
            FilterSheet(filters: filterBinding) {
                router.openSearch()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var filterBinding: Binding<SearchFilters> {
        Binding(get: { router.filters }, set: { router.filters = $0 })
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "Good morning" : (hour < 17 ? "Good afternoon" : "Good evening")
        if let name = store.currentUser?.firstName { return "\(part), \(name)" }
        return "\(part),"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                    Text("Where to next?")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                if store.isSignedIn {
                    NavigationLink(value: Route.notifications) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface, in: .circle)
                            .overlay(alignment: .topTrailing) {
                                if store.unreadNotificationCount > 0 {
                                    Circle().fill(Theme.accent).frame(width: 10, height: 10).offset(x: -8, y: 8)
                                }
                            }
                    }
                    .accessibilityLabel("Notifications")
                }
            }
            HStack(spacing: 10) {
                Button {
                    router.openSearch(focus: true)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                        Text("Homes, hotels, areas…").foregroundStyle(Theme.muted)
                        Spacer()
                    }
                    .font(.body)
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(Theme.surface, in: .capsule)
                }
                .buttonStyle(PressableButtonStyle())
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 54, height: 54)
                        .background(Theme.surface, in: .circle)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Filters")
            }
        }
        .padding(.horizontal, 16)
    }

    private var categoryTiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array([ListingCategory.rent, .shortlet, .hotel, .sale].enumerated()), id: \.element) { index, category in
                NavigationLink(value: Route.category(category)) {
                    CategoryTile(category: category, count: store.liveListings(in: category).count)
                }
                .buttonStyle(PressableButtonStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(Double(index) * 0.07), value: appeared)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var featuredSection: some View {
        let featured = store.featuredListings
        if !featured.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Featured Homes", actionTitle: "See All") { router.openSearch(category: nil) }
                carousel(featured) { FeaturedListingCard(listing: $0) }
            }
        }
    }

    @ViewBuilder
    private var hotelSection: some View {
        let hotels = store.topHotels
        if !hotels.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Top Hotels", actionTitle: "See All") { router.push(.category(.hotel)) }
                carousel(hotels) { HotelCard(listing: $0) }
            }
        }
    }

    @ViewBuilder
    private var shortletSection: some View {
        let shortlets = store.popularShortlets
        if !shortlets.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Popular Shortlets", actionTitle: "See All") { router.push(.category(.shortlet)) }
                carousel(shortlets) { ShortletCard(listing: $0) }
            }
        }
    }

    @ViewBuilder
    private var saleSection: some View {
        let sales = store.liveListings(in: .sale)
        if !sales.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "For Sale", actionTitle: "See All") { router.push(.category(.sale)) }
                carousel(sales) { FeaturedListingCard(listing: $0, width: 260) }
            }
        }
    }

    private func carousel<Card: View>(_ listings: [Listing], @ViewBuilder card: @escaping (Listing) -> Card) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(listings) { listing in
                    NavigationLink(value: Route.listing(listing.id)) {
                        card(listing)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}

struct CategoryTile: View {
    let category: ListingCategory
    let count: Int

    var body: some View {
        Color.clear
            .frame(height: 150)
            .overlay { ListingPhoto(name: category.heroImage) }
            .overlay {
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.68)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topLeading) {
                Image(systemName: category.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.92), in: .circle)
                    .padding(10)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.serviceTitle)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(count) \(category == .hotel ? "hotel" : "listing")\(count == 1 ? "" : "s")")
                            .font(.footnote.weight(.medium))
                            .monospacedDigit()
                            .opacity(0.9)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(12)
            }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            .accessibilityElement(children: .combine)
    }
}
