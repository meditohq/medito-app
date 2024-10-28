import SwiftUI
import WidgetKit
import SwiftUI

struct StreakWidgetMediumView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                Text("\(entry.streakValue)")
                    .font(.custom(MeditoFont.dmSerifRegular, size: 50))
                    .foregroundColor(Color.white)
                Text("\(entry.streakTitle)")
                    .font(.custom(MeditoFont.teachersRegular, size: 16))
                    .foregroundColor(Color.accentPurple)
            }
            HStack(spacing: 20) {
                ForEach(weekDays(), id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(formatWeekDay(date))
                            .font(.system(size: 12))
                            .foregroundColor(Color.gray)
                        
                        ZStack {
                            Circle()
                                .fill(hasTimestamp(on: date) ? Color.accentPurple : Color.moon)
                                .frame(width: 24, height: 24)
                            if hasTimestamp(on: date) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .widgetBackground(Color.deepBlue)
    }
    
    // Helper function to get array of dates for the last 5 days
    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Create array of dates for the last 5 days
        return (-4...0).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: today)
        }
    }
    
    // Helper function to format weekday as single letter
    private func formatWeekDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter format
        return formatter.string(from: date).uppercased()
    }
    
    private func hasTimestamp(on day: Date) -> Bool {
        let calendar = Calendar.current
        return entry.audioCompleted.contains { timestamp in
            let date = Date(timeIntervalSince1970: timestamp/1000)
            return calendar.isDate(date, inSameDayAs: day)
        }
    }
}

//struct StreakWidgetView_Previews: PreviewProvider {
//    static var previews: some View {
//        StreakWidgetMediumView(entry: StatsWidgetEntry(
//            date: Date(),
//            streakTitle: "Today",
//            streakValue: 30,
//            audioCompleted: []
//        ))
//        .previewContext(WidgetPreviewContext(family: .systemLarge))
//        .previewDisplayName("Empty")
//    }
//}
