import SwiftUI
import WidgetKit

@main
struct MeditoWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        ConsistencyWidget()
    }
}
