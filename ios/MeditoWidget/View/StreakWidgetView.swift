import SwiftUI
import WidgetKit
import SwiftUI

struct StreakWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("medito")
            Text(entry.streakTitle)
            Text("\(entry.streakValue)")
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
                    Circle()
                        .fill(hasTimestamp(on: day) ? Color.red : Color.white)
                        .frame(width: 20, height: 20)
                }
            }
            Image(systemName: "flame")
        }
    }

    // Helper function to check if there is a timestamp for a specific day
    private func hasTimestamp(on day: Date) -> Bool {
        print(day)
        return entry.audioCompleted.contains { timestamp in
            Calendar.current.isDate(Date(timeIntervalSince1970: timestamp), inSameDayAs: day)
        }
    }
}
