import SwiftUI
import WidgetKit

struct StreakWidgetView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("medito")
            Text(entry.streakTitle)
            Text("\(entry.streakValue)")
            Text(entry.isMeditationDoneToday ? "Done" : "Not done")
            Image(systemName: "flame")
        }
    }
}
