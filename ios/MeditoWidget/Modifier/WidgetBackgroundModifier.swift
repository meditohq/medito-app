import Foundation
import SwiftUI
import WidgetKit

private struct WidgetBackgroundModifier: ViewModifier {
    private let color: Color
    
    init(_ color: Color) {
        self.color = color
    }
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    color
                }
        } else {
            content
                .background(color)
        }
    }
}

extension View {
    public func widgetBackground(_ color: Color) -> some View {
        self.modifier(WidgetBackgroundModifier(color))
    }
}
