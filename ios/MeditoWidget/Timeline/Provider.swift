import Foundation
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StatsWidgetEntry{
        StatsWidgetEntry(date: Date(), streakTitle: "", streakValue: 0, audioCompleted: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsWidgetEntry) -> ()) {
        let prefs = UserDefaults(suiteName: "group.org.medito.widget")
        let streakTitle = prefs?.string(forKey: "streakTitle") ?? ""
        let streakValue = prefs?.integer(forKey: "streakValue") ?? 0
        let audioCompleted = prefs?.array(forKey: "audioCompleted") as? [TimeInterval] ?? []
        let entry = StatsWidgetEntry(date: Date(), streakTitle: streakTitle, streakValue: streakValue, audioCompleted: audioCompleted)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}
