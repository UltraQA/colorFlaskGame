import SwiftUI

struct FlaskTubeView: View {
    let flask: Flask
    let isSelected: Bool

    private let sectionHeight: CGFloat = 28
    private let flaskWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .fill(DSColor.surface.opacity(0.45))

                liquidStack
                    .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.md))
                    .padding(.horizontal, 7)
                    .padding(.bottom, 7)

                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .stroke(
                        isSelected ? DSColor.brand : DSColor.textPrimary.opacity(0.35),
                        lineWidth: isSelected ? 4 : 2
                    )
            }
            .frame(width: flaskWidth, height: 144)
            .offset(y: isSelected ? -12 : 0)
            .shadow(color: isSelected ? DSColor.brand.opacity(0.24) : .black.opacity(0.08), radius: isSelected ? 14 : 8, x: 0, y: 8)
            .animation(.snappy(duration: 0.2), value: isSelected)
        }
        .frame(width: 84, height: 168)
        .accessibilityLabel("Flask")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var liquidStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(flask.colors.reversed().enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(color)
                    .frame(height: sectionHeight)
            }
        }
    }
}
