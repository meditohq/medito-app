import WidgetKit
import SwiftUI

@main
struct MeditoWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidgetSmall()
        StreakWidgetMedium()
    }
}
