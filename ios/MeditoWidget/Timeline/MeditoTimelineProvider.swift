import Foundation
import WidgetKit

struct MeditoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeditoWidgetEntry{
        MeditoWidgetEntry(date: Date(), streakValue: 0, audioCompleted: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (MeditoWidgetEntry) -> ()) {
        let prefs = UserDefaults(suiteName: "group.org.medito.widget")
        let streakValue = prefs?.integer(forKey: "streakValue") ?? 0
        let audioCompleted = prefs?.array(forKey: "audioCompleted") as? [TimeInterval] ?? []
        let entry = MeditoWidgetEntry(date: Date(), streakValue: streakValue, audioCompleted: audioCompleted)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}
