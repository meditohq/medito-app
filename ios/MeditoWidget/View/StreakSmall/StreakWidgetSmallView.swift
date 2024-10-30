import SwiftUI

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
                .foregroundColor(Color.accentPurple)
        }
        .widgetBackground(Color.deepBlue)
    }
}
