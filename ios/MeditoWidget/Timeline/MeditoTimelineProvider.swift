import WidgetKit
import SwiftUI

struct MeditoTimelineProvider: TimelineProvider {
    typealias Entry = MeditoWidgetEntry
    
    func placeholder(in context: Context) -> MeditoWidgetEntry {
        MeditoWidgetEntry(date: Date(), currentStreak: 0, bestStreak: 0, totalMinutes: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeditoWidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeditoWidgetEntry>) -> ()) {
        let entry = loadWidgetData()
        
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadWidgetData() -> MeditoWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.org.medito.widget")
        
        let currentStreak = defaults?.integer(forKey: "widget_current_streak") ?? 0
        let bestStreak = defaults?.integer(forKey: "widget_best_streak") ?? 0
        let totalMinutes = defaults?.integer(forKey: "widget_total_time_mins") ?? 0
        
        return MeditoWidgetEntry(
            date: Date(),
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalMinutes: totalMinutes
        )
    }
} 
