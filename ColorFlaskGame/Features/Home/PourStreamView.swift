import SwiftUI

struct PourStreamView: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let scale: CGFloat
    let reduceMotion: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            let controlOffset = max(abs(to.x - from.x) * 0.36, 40 * scale)
            let firstControl = CGPoint(x: from.x + controlOffset * direction, y: from.y - 54 * scale)
            let secondControl = CGPoint(x: to.x - controlOffset * direction, y: to.y - 44 * scale)

            path.move(to: from)
            path.addCurve(to: to, control1: firstControl, control2: secondControl)

            context.stroke(
                path.trimmedPath(from: 0, to: progress),
                with: .color(color.opacity(0.92)),
                style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round, lineJoin: .round)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else {
                progress = 1
                return
            }

            withAnimation(.easeInOut(duration: 0.48)) {
                progress = 1
            }
        }
    }

    private var direction: CGFloat {
        to.x >= from.x ? 1 : -1
    }
}
