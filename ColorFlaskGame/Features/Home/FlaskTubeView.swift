import SwiftUI

enum FlaskVisualState: Equatable {
    case normal
    case empty
    case selected
    case invalidTarget
    case completed
    case lockedBonus
    case hintSource
    case hintTarget
}

struct FlaskTubeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let flask: Flask
    let flaskIndex: Int
    let visualState: FlaskVisualState

    private var bottleImageWidth: CGFloat {
        GameMetric.flaskHeight * 0.375
    }

    private var liquidColumnWidth: CGFloat {
        bottleImageWidth - 12
    }

    private var liquidColumnHeight: CGFloat {
        GameMetric.flaskHeight - 34
    }

    private var sectionHeight: CGFloat {
        liquidColumnHeight / CGFloat(Flask.maxCapacity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            bottleGlow
            hintHalo

            liquidStack
                .frame(width: liquidColumnWidth, height: liquidColumnHeight, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.bottom, 6)

            Image("FlaskBottle")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: bottleImageWidth, height: GameMetric.flaskHeight)
                .opacity(flask.isPlayable ? 1 : 0.48)

            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    strokeColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        dash: strokeDash
                    )
                )

            if !flask.isPlayable {
                lockedOverlay
            }

            stateIndicator
            hintRoleCue
        }
        .frame(width: GameMetric.flaskWidth, height: GameMetric.flaskHeight)
        .scaleEffect(visualState == .hintSource ? 1.04 : 1)
        .rotationEffect(visualState == .hintSource && !reduceMotion ? .degrees(-2.5) : .zero)
        .offset(y: verticalOffset)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowYOffset
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: visualState)
        .frame(width: GameMetric.flaskHitWidth, height: GameMetric.flaskHitHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flask \(flaskIndex + 1)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var bottleGlow: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(flask.isPlayable ? GameColor.glassFill.opacity(0.72) : GameColor.glassFill.opacity(0.34))
            .frame(width: bottleImageWidth - 4, height: GameMetric.flaskHeight - 10)
            .padding(.bottom, 2)
            .blur(radius: 1.2)
    }

    @ViewBuilder
    private var hintHalo: some View {
        switch visualState {
        case .hintSource, .hintTarget:
            HintHaloView(
                color: visualState == .hintSource ? GameColor.controlAccent : GameColor.hintTarget,
                reduceMotion: reduceMotion,
                isTarget: visualState == .hintTarget
            )
            .frame(width: GameMetric.flaskWidth + 18, height: GameMetric.flaskHeight + 18)
            .padding(.bottom, -2)
        default:
            EmptyView()
        }
    }

    private var liquidStack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ForEach(Array(flask.colors.reversed().enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.swiftUIColor.opacity(0.82),
                                color.swiftUIColor,
                                color.swiftUIColor.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: sectionHeight)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private var strokeColor: Color {
        if !flask.isPlayable {
            return GameColor.lockedStroke
        }

        switch visualState {
        case .selected:
            return GameColor.selectedStroke
        case .invalidTarget:
            return GameColor.invalid
        case .completed:
            return GameColor.successAccent
        case .hintSource:
            return GameColor.controlAccent
        case .hintTarget:
            return GameColor.hintTarget
        case .normal, .empty, .lockedBonus:
            return GameColor.glassStroke.opacity(0.82)
        }
    }

    private var strokeWidth: CGFloat {
        switch visualState {
        case .selected, .invalidTarget, .hintSource:
            return 4
        case .hintTarget:
            return 5
        default:
            return 3
        }
    }

    private var strokeDash: [CGFloat] {
        if !flask.isPlayable {
            return [8, 8]
        }

        switch visualState {
        case .hintSource:
            return [10, 5]
        default:
            return []
        }
    }

    private var shadowColor: Color {
        switch visualState {
        case .selected:
            return GameColor.selectedGlow.opacity(0.34)
        case .invalidTarget:
            return GameColor.invalid.opacity(0.34)
        case .hintSource:
            return GameColor.controlAccent.opacity(0.32)
        case .hintTarget:
            return GameColor.hintTarget.opacity(0.38)
        case .completed:
            return GameColor.successAccent.opacity(0.3)
        default:
            return .black.opacity(0.28)
        }
    }

    private var verticalOffset: CGFloat {
        switch visualState {
        case .selected:
            return -14
        case .hintSource:
            return -10
        default:
            return 0
        }
    }

    private var shadowRadius: CGFloat {
        switch visualState {
        case .selected:
            return 18
        case .hintSource, .hintTarget:
            return 20
        default:
            return 12
        }
    }

    private var shadowYOffset: CGFloat {
        switch visualState {
        case .selected:
            return 12
        case .hintSource:
            return 14
        default:
            return 10
        }
    }

    @ViewBuilder
    private var hintRoleCue: some View {
        switch visualState {
        case .hintSource:
            sourcePourCue
        case .hintTarget:
            targetLandingCue
        default:
            EmptyView()
        }
    }

    private var sourcePourCue: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(GameColor.controlAccent)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(GameColor.controlSurface.opacity(0.86))
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.55), lineWidth: 1.5)
            )
            .shadow(color: GameColor.controlAccent.opacity(0.24), radius: 8, x: 0, y: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: -12, y: -16)
            .accessibilityHidden(true)
    }

    private var targetLandingCue: some View {
        ZStack {
            Circle()
                .stroke(GameColor.hintTarget.opacity(0.88), lineWidth: 4)
                .frame(width: 42, height: 42)

            Circle()
                .fill(GameColor.hintTarget.opacity(0.18))
                .frame(width: 28, height: 28)

            Image(systemName: "plus")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.hintTarget)
        }
        .shadow(color: GameColor.hintTarget.opacity(0.26), radius: 8, x: 0, y: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: 16)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch visualState {
        case .selected:
            indicatorSymbol(
                systemName: "arrowtriangle.up.fill",
                foreground: GameColor.controlSurface,
                background: GameColor.selectedStroke,
                size: 24
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -10)

        case .invalidTarget:
            indicatorSymbol(
                systemName: "exclamationmark",
                foreground: .white,
                background: GameColor.invalid,
                size: 26
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 9, y: -9)

        case .hintSource:
            indicatorSymbol(
                systemName: "drop.fill",
                foreground: GameColor.controlSurface,
                background: GameColor.controlAccent,
                size: 25
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -9)

        case .hintTarget:
            indicatorSymbol(
                systemName: "scope",
                foreground: GameColor.controlSurface,
                background: GameColor.hintTarget,
                size: 28
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -9)

        case .completed:
            indicatorSymbol(
                systemName: "checkmark",
                foreground: GameColor.controlSurface,
                background: GameColor.successAccent,
                size: 24
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -9)

        case .normal, .empty, .lockedBonus:
            EmptyView()
        }
    }

    private func indicatorSymbol(
        systemName: String,
        foreground: Color,
        background: Color,
        size: CGFloat
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(background)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.92), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 4)
    }

    private var accessibilityValue: String {
        if !flask.isPlayable {
            return "Locked bonus flask. Empty."
        }

        var values: [String] = []

        switch visualState {
        case .selected:
            values.append("Selected")
        case .invalidTarget:
            values.append("Invalid target")
        case .hintSource:
            values.append("Hint source")
        case .hintTarget:
            values.append("Hint target")
        case .completed:
            values.append("Completed")
        case .empty:
            values.append("Empty")
        case .normal, .lockedBonus:
            values.append("Not selected")
        }

        values.append(contentsSummary)

        if let topColor = flask.topColor {
            values.append("Top color: \(topColor.accessibilityName)")
        }

        values.append("\(flask.freeSpace) empty sections")

        return values.joined(separator: ". ")
    }

    private var accessibilityHint: String {
        if !flask.isPlayable {
            return "Double tap to open bonus flask options."
        }

        if visualState == .selected {
            return "Double tap another flask to pour this potion."
        }

        if visualState == .hintSource {
            return "Suggested pour source."
        }

        if visualState == .hintTarget {
            return "Suggested pour target."
        }

        if flask.isEmpty {
            return "Double tap to use as a target flask."
        }

        return "Double tap to select this flask as the pour source."
    }

    private var contentsSummary: String {
        guard !flask.colors.isEmpty else {
            return "No potion sections"
        }

        let colors = flask.colors
            .map(\.accessibilityName)
            .joined(separator: ", ")

        return "Contents from bottom: \(colors)"
    }

    private var lockedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(GameColor.lockedOverlay)

            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(GameColor.glassStroke.opacity(0.82))
                .padding(18)
                .background(
                    Circle()
                        .fill(GameColor.controlSurface.opacity(0.72))
                )
        }
        .padding(8)
    }
}

private struct HintHaloView: View {
    let color: Color
    let reduceMotion: Bool
    let isTarget: Bool

    var body: some View {
        if reduceMotion {
            halo(phase: 0.2)
        } else {
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.4) / 1.4
                halo(phase: phase)
            }
        }
    }

    private func halo(phase: TimeInterval) -> some View {
        let progress = CGFloat(phase)
        let scale = isTarget ? 1 + progress * 0.08 : 1 + progress * 0.04
        let opacity = isTarget ? 0.48 - progress * 0.22 : 0.36 - progress * 0.16

        return RoundedRectangle(cornerRadius: 31)
            .stroke(
                color.opacity(max(0.16, opacity)),
                style: StrokeStyle(
                    lineWidth: isTarget ? 5 : 3,
                    lineCap: .round,
                    dash: isTarget ? [7, 6] : []
                )
            )
            .scaleEffect(scale)
            .blur(radius: isTarget ? 0.4 : 1.2)
    }
}
