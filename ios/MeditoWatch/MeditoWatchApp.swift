import SwiftUI

@main
struct MeditoWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    init() {
        // Activate WatchConnectivity at launch so the last context is restored
        // before the first frame.
        _ = WatchStore.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { phase in
                    if phase == .active { WatchStore.shared.refresh() }
                }
        }
    }
}
