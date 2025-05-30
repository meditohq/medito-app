import WidgetKit
import SwiftUI

struct MeditoWidgetEntryView: View {
    var entry: MeditoWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: MeditoWidgetEntry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(entry.currentStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Text("Day Streak")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("\(entry.totalMinutes) mins")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct MediumWidgetView: View {
    let entry: MeditoWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(entry.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("\(entry.bestStreak)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("\(entry.totalMinutes)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Total Minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
} 