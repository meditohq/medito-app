import SwiftUI

struct FlameImageView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var isDoneToday: Bool {
        entry.audioCompleted.contains { timeInterval in
            Calendar.current.isDateInToday(Date(timeIntervalSince1970: timeInterval/1000))
        }
    }
    
    var body: some View {
        if entry.streakValue == 0 {
            Image(systemName: "flame")
                .foregroundColor(Color.moon)
        } else if isDoneToday {
            Image(systemName: "flame.fill")
                .foregroundColor(Color.accentPurple)
        } else {
            Image(systemName: "flame.fill")
                .foregroundColor(Color.white)
        }
    }
}
