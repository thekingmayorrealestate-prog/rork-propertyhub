import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if !store.isSignedIn {
                SignInPrompt(title: "Save homes you love", message: "Sign in to keep a shortlist of rentals, shortlets and properties for sale.", symbol: "heart")
            } else if store.favoriteListings.isEmpty {
                ContentUnavailableView {
                    Label("No saved homes yet", systemImage: "heart")
                } description: {
                    Text("Tap the heart on any listing to add it here.")
                } actions: {
                    Button("Explore homes") { router.openSearch() }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 220)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.favoriteListings) { listing in
                            NavigationLink(value: Route.listing(listing.id)) {
                                ListingRow(listing: listing)
                                    .opacity(listing.status == .live ? 1 : 0.6)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .animation(.spring, value: store.favoriteListings.map(\.id))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .navigationTitle("Saved")
    }
}
