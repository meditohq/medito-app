import SwiftUI

enum StreakWidgetSmallViewConstants {
    static let flameFontSize: CGFloat = 38
}

struct StreakWidgetSmallView: View {
    typealias Constants = StreakWidgetSmallViewConstants
    
    var entry: MeditoTimelineProvider.Entry
    
    var isDoneToday: Bool {
        entry.audioCompleted.contains { timeInterval in
            Calendar.current.isDateInToday(Date(timeIntervalSince1970: timeInterval/1000))
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .center, spacing: 8) {
                if isDoneToday {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color.accentPurple)
                        .font(.system(size: Constants.flameFontSize))
                } else {
                    Image(systemName: "flame")
                        .foregroundColor(Color.moon)
                        .font(.system(size: Constants.flameFontSize))
                }
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
