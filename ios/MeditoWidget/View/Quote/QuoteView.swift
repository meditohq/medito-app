import SwiftUI
import WidgetKit

struct QuoteView: View {
    var text: String
    
    var body: some View {
        Text(text)
            .font(.custom(MeditoFont.sourceSerifRegular, size: 16))
            .foregroundColor(Color.white)
            .minimumScaleFactor(0.6)
    }
}
