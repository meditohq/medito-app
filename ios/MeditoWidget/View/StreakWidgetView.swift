import SwiftUI
import WidgetKit

struct StreakWidgetView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("medito")
            Text(entry.title)
            Text(entry.subtitle)
            Image(systemName: "flame")
        }
    }
}
