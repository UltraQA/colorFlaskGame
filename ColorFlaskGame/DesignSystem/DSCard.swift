import SwiftUI

struct DSCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DSSpacing.lg)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSCornerRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .stroke(DSColor.stroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}
