import SwiftUI
import WidgetKit

struct StreakWidgetMediumView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            topView
            weekView
            
            if let lastUpdated = entry.lastUpdated {
                Text("Updated: \(lastUpdated)")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.top, 5)
            }
        }
        .widgetBackground(Color.deepBlue)
        .donationLayer(didDonate: entry.isMonthlyDonor)
    }
    
    var topView: some View {
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
                    .layoutPriority(1)
            }
        }
    }
    
    @ViewBuilder
    var weekView: some View {
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

struct StreakWidgetMediumView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with a full week streak
            StreakWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 52,
                audioCompleted: [
                    Date().timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-172800).timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-259200).timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-345600).timeIntervalSince1970 * 1000
                ],
                isMonthlyDonor: true,
                dailyQuote: "",
                lastUpdated: "01 Jun 2023, 14:30"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))  // Fixed widget family
            .previewDisplayName("Full week")
            
            // Preview with a broken streak
            StreakWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 2,
                audioCompleted: [
                    Date().timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-259200).timeIntervalSince1970 * 1000
                ],
                isMonthlyDonor: true,
                dailyQuote: "",
                lastUpdated: "01 Jun 2023, 14:30"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Broken")
            
            // Preview with no streak
            StreakWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 0,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: "",
                lastUpdated: "01 Jun 2023, 14:30"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("No Streak")
            
            // Preview with previous days complete but not today
            StreakWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 156,
                audioCompleted: [
                    Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000,  // yesterday
                    Date().addingTimeInterval(-172800).timeIntervalSince1970 * 1000, // 2 days ago
                    Date().addingTimeInterval(-259200).timeIntervalSince1970 * 1000, // 3 days ago
                    Date().addingTimeInterval(-345600).timeIntervalSince1970 * 1000  // 4 days ago
                ],
                isMonthlyDonor: true,
                dailyQuote: "",
                lastUpdated: "01 Jun 2023, 14:30"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Not Today")
            
            // Donate
            StreakWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 2,
                audioCompleted: [
                    Date().timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000,
                    Date().addingTimeInterval(-259200).timeIntervalSince1970 * 1000
                ],
                isMonthlyDonor: false,
                dailyQuote: "",
                lastUpdated: "01 Jun 2023, 14:30"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Donate")
        }
    }
}
extension Color {
    // Function to blend with another color
    func blend(with color: Color, opacity: Double) -> Color {
        // Convert colors to RGB components
        guard let components1 = self.cgColor?.components,
              let components2 = color.cgColor?.components else {
            return self
        }
        
        // Extract RGB values for first color
        let r1 = Double(components1[0])
        let g1 = Double(components1[1])
        let b1 = Double(components1[2])
        
        // Extract RGB values for second color
        let r2 = Double(components2[0])
        let g2 = Double(components2[1])
        let b2 = Double(components2[2])
        
        // Blend colors using opacity
        let r = r1 * (1 - opacity) + r2 * opacity
        let g = g1 * (1 - opacity) + g2 * opacity
        let b = b1 * (1 - opacity) + b2 * opacity
        
        return Color(red: r, green: g, blue: b)
    }
}
