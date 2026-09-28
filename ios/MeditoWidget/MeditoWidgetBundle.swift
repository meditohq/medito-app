import SwiftUI
import WidgetKit

@main
struct MeditoWidgetBundle: WidgetBundle {
    init() {
        _ = WidgetFonts.register
    }

    var body: some Widget {
        StreakWidget()
        ConsistencyWidget()
        UpNextWidget()
    }
}
