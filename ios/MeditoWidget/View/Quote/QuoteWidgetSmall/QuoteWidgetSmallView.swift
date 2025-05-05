import SwiftUI
import WidgetKit

struct QuoteWidgetSmallView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            QuoteView(text: entry.dailyQuote)
        }
        .widgetBackground(Color.deepBlue)
        .donationLayer(didDonate: entry.isMonthlyDonor)
    }
}

struct QuoteWidgetSmallView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuoteWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Normal")
            
            QuoteWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Long")
            
            QuoteWidgetSmallView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: false,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Donate")
        }
    }
}
