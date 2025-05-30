import SwiftUI
import WidgetKit

struct StreakWidgetMedium: View {
    let entry: MeditoWidgetEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    FlameImageView()
                    Text("\(entry.currentStreak)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(entry.totalMinutes)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Total Minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
} 