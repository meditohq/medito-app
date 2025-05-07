import Foundation
import WidgetKit

struct MeditoWidgetEntry: TimelineEntry {
    var date: Date
    var streakValue: Int
    var audioCompleted: [TimeInterval]
    var isMonthlyDonor: Bool
    var dailyQuote: String
    var lastUpdated: String?
}
