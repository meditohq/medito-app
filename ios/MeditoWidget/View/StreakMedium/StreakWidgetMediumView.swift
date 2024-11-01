import SwiftUI
import WidgetKit
import SwiftUI

struct StreakWidgetMediumView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                FlameImageView(entry: entry)
                    .font(.system(size: 23))
                HStack(spacing: 8) {
                    Text("\(entry.streakValue)")
                        .font(.custom(MeditoFont.teachersBold, size: 30))
                        .foregroundColor(Color.white)
                    Text("day streak")
                        .font(.custom(MeditoFont.teachersRegular, size: 30))
                        .foregroundColor(Color.white)
                }
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
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                
                                // Add connecting line to next day if part of streak
                                if isPartOfStreak(date) {
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 2)
                                        .offset(x: 22)
                                }
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
    
    // Helper function to check if a date is part of a streak
    private func isPartOfStreak(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
        
        // Check if both current day and next day have timestamps
        return hasTimestamp(on: date) && hasTimestamp(on: nextDay)
    }
}
