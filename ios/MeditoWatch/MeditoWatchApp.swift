import SwiftUI

@main
struct MeditoWatchApp: App {
    init() {
        // Activate WatchConnectivity at launch so the last context is restored
        // before the first frame.
        _ = WatchStore.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
