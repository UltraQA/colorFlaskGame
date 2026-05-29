import SwiftUI

struct PourStreamView: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let scale: CGFloat
    let reduceMotion: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Canvas { context, _ in
                let path = pourPath
                let visiblePath = path.trimmedPath(from: 0, to: progress)

                context.stroke(
                    visiblePath,
                    with: .color(color.opacity(0.22)),
                    style: StrokeStyle(lineWidth: 18 * scale, lineCap: .round, lineJoin: .round)
                )

                context.stroke(
                    visiblePath,
                    with: .linearGradient(
                        Gradient(colors: [
                            color.opacity(0.58),
                            color.opacity(0.98),
                            .white.opacity(0.34)
                        ]),
                        startPoint: from,
                        endPoint: to
                    ),
                    style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round, lineJoin: .round)
                )

                context.stroke(
                    path.trimmedPath(from: max(0, progress - 0.18), to: progress),
                    with: .color(.white.opacity(0.24)),
                    style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round)
                )
            }

            if progress > 0.05 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.42),
                                color.opacity(0.95),
                                color.opacity(0.52)
                            ],
                            center: .topLeading,
                            startRadius: 1,
                            endRadius: 8 * scale
                        )
                    )
                    .frame(width: 15 * scale, height: 15 * scale)
                    .shadow(color: color.opacity(0.36), radius: 8 * scale, x: 0, y: 3 * scale)
                    .position(dropPoint)
            }
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

    private var controlOffset: CGFloat {
        max(abs(to.x - from.x) * 0.36, 40 * scale)
    }

    private var firstControl: CGPoint {
        CGPoint(x: from.x + controlOffset * direction, y: from.y - 54 * scale)
    }

    private var secondControl: CGPoint {
        CGPoint(x: to.x - controlOffset * direction, y: to.y - 44 * scale)
    }

    private var pourPath: Path {
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: firstControl, control2: secondControl)
        return path
    }

    private var dropPoint: CGPoint {
        cubicPoint(
            start: from,
            control1: firstControl,
            control2: secondControl,
            end: to,
            progress: min(max(progress, 0), 1)
        )
    }

    private func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        progress: CGFloat
    ) -> CGPoint {
        let remaining = 1 - progress
        let remainingSquared = remaining * remaining
        let progressSquared = progress * progress
        let remainingCubed = remainingSquared * remaining
        let progressCubed = progressSquared * progress
        let x = remainingCubed * start.x
            + 3 * remainingSquared * progress * control1.x
            + 3 * remaining * progressSquared * control2.x
            + progressCubed * end.x
        let y = remainingCubed * start.y
            + 3 * remainingSquared * progress * control1.y
            + 3 * remaining * progressSquared * control2.y
            + progressCubed * end.y
        return CGPoint(x: x, y: y)
    }
}
