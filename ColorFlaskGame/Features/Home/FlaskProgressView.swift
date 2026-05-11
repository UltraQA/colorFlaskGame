import SwiftUI

struct FlaskProgressView: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let height = proxy.size.height

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(DSColor.stroke.opacity(0.6))

                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [DSColor.success, DSColor.brand],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: height * clampedProgress)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .stroke(DSColor.textPrimary.opacity(0.16), lineWidth: 2)
            }
        }
        .frame(width: 96, height: 180)
        .accessibilityLabel("Game progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
