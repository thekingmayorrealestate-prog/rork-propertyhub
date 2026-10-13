import SwiftUI

@main
struct HomesteadApp: App {
    @State private var store = AppStore()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(router)
                .preferredColorScheme(.light)
                .tint(Theme.primary)
        }
    }
}
