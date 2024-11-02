import SwiftUI
import WidgetKit

struct StreakWidgetSmallView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                FlameImageView(entry: entry)
                    .font(.system(size: 38))
                Text("\(entry.streakValue)")
                    .font(.custom(MeditoFont.teachersBold, size: 50))
                    .foregroundColor(Color.white)
                    .minimumScaleFactor(0.3)
            }
            Text("day streak")
                .font(.custom(MeditoFont.teachersRegular, size: 16))
                .foregroundColor(Color.white)
        }
        .widgetBackground(Color.deepBlue)
        .donationLayer(didDonate: entry.isMonthlyDonor)
    }
}

struct StreakWidgetSmallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Done today - active streak
            StreakWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [
                    Date().timeIntervalSince1970 * 1000  // today
                ],
                isMonthlyDonor: true,
                dailyQuote: ""
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Done Today")
            
            // Not done today
            StreakWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 6,
                audioCompleted: [
                    Date().addingTimeInterval(-86400).timeIntervalSince1970 * 1000  // yesterday
                ],
                isMonthlyDonor: true,
                dailyQuote: ""
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Not Done Today")
            
            // Zero streak
            StreakWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 0,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: ""
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Zero Streak")
            
            // Donate!
            StreakWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [
                    Date().timeIntervalSince1970 * 1000  // today
                ],
                isMonthlyDonor: false,
                dailyQuote: ""
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Donate")
        }
    }
}
