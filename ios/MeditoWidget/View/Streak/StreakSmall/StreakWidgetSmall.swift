import SwiftUI
import WidgetKit

struct StreakWidgetSmall: View {
    let entry: MeditoWidgetEntry
    
    var body: some View {
        VStack {
            HStack {
                FlameImageView()
                Text("\(entry.currentStreak)")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            Text("Day Streak")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
} 