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
                donateCapsule
            }
        }
        .widgetBackground(didDonate ? Color.deepBlue : Color.overlayBlend)
    }
    
    @ViewBuilder
    var donateCapsule: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.white)
            Text("Donate")
                .font(.custom(MeditoFont.teachersRegular, size: 16))
                .foregroundColor(Color.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.deepBlue)
        )
    }
}

extension View {
    public func donationLayer(didDonate: Bool) -> some View {
        self.modifier(DonateModifier(didDonate: didDonate))
    }
}
