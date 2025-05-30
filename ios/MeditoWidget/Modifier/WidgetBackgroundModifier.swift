import SwiftUI

struct WidgetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
    }
} 