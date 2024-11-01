import Foundation
import SwiftUI
import WidgetKit

private struct DonateModifier: ViewModifier {
    private let didDonate: Bool
    
    init(didDonate: Bool) {
        self.didDonate = didDonate
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if !didDonate {
                Color.overlay
                Text("Donate")
                    .font(.custom(MeditoFont.dmSerifRegular, size: 12))
                    .foregroundColor(Color.deepBlue)
            }
        }
        .widgetBackground(didDonate ? Color.deepBlue : Color.overlayBlend)
    }
}

extension View {
    public func donationLayer(didDonate: Bool) -> some View {
        self.modifier(DonateModifier(didDonate: didDonate))
    }
}
