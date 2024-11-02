import SwiftUI
import WidgetKit

struct QuoteWidgetMediumView: View {
    var entry: MeditoTimelineProvider.Entry
    
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            QuoteView(text: entry.dailyQuote)
        }
        .widgetBackground(Color.deepBlue)
        .donationLayer(didDonate: entry.isMonthlyDonor)
    }
}

struct QuoteWidgetMediumView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            QuoteWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Normal")
            
            QuoteWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: true,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Long")
            
            QuoteWidgetMediumView(entry: MeditoWidgetEntry(
                date: Date(),
                streakValue: 7,
                audioCompleted: [],
                isMonthlyDonor: false,
                dailyQuote: "This is my daily quote. This is my daily quote. This is my daily quote."
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Donate")
        }
    }
}
