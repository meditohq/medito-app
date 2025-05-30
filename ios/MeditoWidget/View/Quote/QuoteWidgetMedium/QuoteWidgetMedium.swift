import SwiftUI
import WidgetKit

struct QuoteWidgetMedium: View {
    let entry: MeditoWidgetEntry
 
    var body: some View {
        QuoteView(entry: entry)
    }
} 