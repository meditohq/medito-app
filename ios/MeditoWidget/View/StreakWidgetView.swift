import SwiftUI
import WidgetKit
import SwiftUI

struct StreakWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
            VStack {
                Text("\(entry.streakValue)")
                    .font(.system(size: 40))
                Text("\(entry.streakTitle)")
                    .font(.system(size: 20))
                HStack(spacing: 12) {
                    ForEach(weekDays(), id: \.self) { date in
                        VStack(spacing: 4) {
                            Text(formatWeekDay(date))
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray)
                            
                            ZStack {
                                Circle()
                                    .fill(hasTimestamp(on: date) ? Color(.sRGB, red: 145/255, green: 125/255, blue: 240/255, opacity: 1) : Color(.sRGB, red: 79/255, green: 79/255, blue: 102/255, opacity: 1))
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
        .containerBackground(for: .widget) {
            Color(.sRGB, red: 33/255, green: 31/255, blue: 38/255, opacity: 1)
        }
    }
    
    // Helper function to get array of dates for Monday-Friday
    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the most recent Monday
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday = 2
        
        guard let monday = calendar.date(from: components) else { return [] }
        
        // Create array of dates from Monday to Friday only
        return (0...4).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monday)
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
        let contains = entry.audioCompleted.contains { timestamp in
            let date = Date(timeIntervalSince1970: timestamp/1000)
            return calendar.isDate(date, inSameDayAs: day)
        }
        return contains
    }
}
