import SwiftUI

struct QuoteView: View {
    let entry: MeditoWidgetEntry
    
    var body: some View {
        VStack {
            Text("Daily Meditation")
                .font(.headline)
            
            Text("Find peace within")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
} 