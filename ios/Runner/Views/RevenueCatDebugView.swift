import SwiftUI
import RevenueCatUI

struct RevenueCatDebugView: View {
    var body: some View {
        dummyView
    }
    
    @ViewBuilder
    var dummyView: some View {
        if #available(iOS 16.0, *) {
            Text("Revenue Cat")
                .debugRevenueCatOverlay()
        }
    }
}

#Preview {
    RevenueCatDebugView()
}
