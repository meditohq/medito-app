import Foundation
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StatsWidgetEntry{
        StatsWidgetEntry(date: Date(), title: "", subtitle: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsWidgetEntry) -> ()) {
        let prefs = UserDefaults(suiteName: "group.org.medito.widget")
        let title = prefs?.string(forKey: "title") ?? ""
        let subtitle = prefs?.string(forKey: "subtitle") ?? ""
        let entry = StatsWidgetEntry(date: Date(), title: title, subtitle: subtitle)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        getSnapshot(in: context) { (entry) in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}
