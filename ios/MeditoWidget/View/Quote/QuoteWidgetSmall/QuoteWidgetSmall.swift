import SwiftUI
import WidgetKit

struct QuoteWidgetSmall: View {
    let entry: MeditoWidgetEntry
 
    var body: some View {
        QuoteView(entry: entry)
    }
} 