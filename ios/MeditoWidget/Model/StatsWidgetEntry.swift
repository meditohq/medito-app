import Foundation
import WidgetKit

struct StatsWidgetEntry: TimelineEntry {
    var date: Date
    var streakTitle: String
    var streakValue: Int
    var isMeditationDoneToday: Bool
}
