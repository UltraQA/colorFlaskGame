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
        GameMetric.flaskWidth * 0.92
    }

    private var liquidColumnWidth: CGFloat {
        bottleImageWidth - 18
    }

    private var liquidColumnHeight: CGFloat {
        GameMetric.flaskHeight - 56
    }

    private var bottleOpacity: Double {
        guard !flask.isPlayable else {
            return 1
        }

        return visualState == .lockedBonus ? 0.66 : 0.48
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            bottleGlow
            hintHalo

            PotionLiquidColumnView(colors: flask.colors)
                .frame(width: liquidColumnWidth, height: liquidColumnHeight, alignment: .bottom)
                .mask(PotionFlaskLiquidShape())
                .padding(.bottom, 14)

            PotionFlaskGlassView(
                visualState: visualState,
                isPlayable: flask.isPlayable,
                bottleOpacity: bottleOpacity
            )
                .frame(width: bottleImageWidth, height: GameMetric.flaskHeight)

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
        PotionBottleShape()
            .fill(bottleGlowColor)
            .frame(width: bottleImageWidth - 4, height: GameMetric.flaskHeight - 10)
            .padding(.bottom, 2)
            .blur(radius: 1.2)
    }

    private var bottleGlowColor: Color {
        if flask.isPlayable {
            return GameColor.glassFill.opacity(0.72)
        }

        if visualState == .lockedBonus {
            return GameColor.bonusFlaskGlow.opacity(0.20)
        }

        return GameColor.glassFill.opacity(0.34)
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
        case .lockedBonus:
            return GameColor.bonusFlaskGlow.opacity(0.34)
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

    @ViewBuilder
    private var lockedOverlay: some View {
        if visualState == .lockedBonus {
            BonusLockedFlaskOverlay(reduceMotion: reduceMotion)
                .frame(width: bottleImageWidth - 8, height: GameMetric.flaskHeight - 18)
                .padding(.bottom, 7)
        } else {
            ZStack {
                PotionBottleShape()
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
            .frame(width: bottleImageWidth - 8, height: GameMetric.flaskHeight - 18)
            .padding(.bottom, 7)
        }
    }
}

private struct PotionLiquidColumnView: View {
    let colors: [LiquidColor]

    var body: some View {
        GeometryReader { proxy in
            let sectionHeight = proxy.size.height / CGFloat(Flask.maxCapacity)
            let filledHeight = min(proxy.size.height, sectionHeight * CGFloat(colors.count))

            ZStack(alignment: .bottom) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    PotionLiquidSectionView(
                        color: color,
                        isTopSection: index == colors.count - 1
                    )
                    .frame(height: sectionHeight + 0.6)
                    .offset(y: -sectionHeight * CGFloat(index))
                }

                if let topColor = colors.last {
                    let surfaceHeight = min(10, sectionHeight * 0.28)

                    LiquidSurfaceView(color: topColor)
                        .frame(width: proxy.size.width * 0.92, height: surfaceHeight)
                        .offset(y: -filledHeight + surfaceHeight / 2 + 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .clipped()
    }
}

private struct PotionLiquidSectionView: View {
    let color: LiquidColor
    let isTopSection: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    color.swiftUIColor.opacity(0.86),
                    color.swiftUIColor,
                    color.swiftUIColor.opacity(0.92)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            LinearGradient(
                colors: [
                    .white.opacity(isTopSection ? 0.22 : 0.14),
                    .clear,
                    .black.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct LiquidSurfaceView: View {
    let color: LiquidColor

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.34),
                        color.swiftUIColor.opacity(0.95),
                        color.swiftUIColor.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.28), lineWidth: 0.8)
            )
            .shadow(color: .white.opacity(0.12), radius: 2, x: 0, y: -1)
    }
}

private struct PotionFlaskGlassView: View {
    let visualState: FlaskVisualState
    let isPlayable: Bool
    let bottleOpacity: Double

    var body: some View {
        ZStack {
            PotionBottleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            GameColor.glassFill.opacity(isPlayable ? 0.22 : 0.10),
                            GameColor.glassFill.opacity(isPlayable ? 0.08 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            PotionBottleShape()
                .stroke(glassStrokeColor, lineWidth: glassStrokeWidth)

            PotionBottleShape()
                .stroke(Color.white.opacity(isPlayable ? 0.22 : 0.12), lineWidth: 1)
                .offset(x: -2, y: -1)
                .blur(radius: 0.4)

            Capsule()
                .fill(Color.white.opacity(isPlayable ? 0.36 : 0.18))
                .frame(width: 24, height: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 21, y: 15)

            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isPlayable ? 0.16 : 0.08))
                .frame(width: 9)
                .padding(.top, 30)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: 15)
        }
        .opacity(bottleOpacity)
    }

    private var glassStrokeColor: Color {
        guard isPlayable else {
            return GameColor.glassStroke.opacity(0.38)
        }

        switch visualState {
        case .selected:
            return GameColor.selectedStroke.opacity(0.92)
        case .invalidTarget:
            return GameColor.invalid.opacity(0.92)
        case .completed:
            return GameColor.successAccent.opacity(0.82)
        case .hintSource:
            return GameColor.controlAccent.opacity(0.9)
        case .hintTarget:
            return GameColor.hintTarget.opacity(0.95)
        case .normal, .empty, .lockedBonus:
            return GameColor.glassStroke.opacity(0.78)
        }
    }

    private var glassStrokeWidth: CGFloat {
        switch visualState {
        case .selected, .invalidTarget, .hintSource:
            return 4
        case .hintTarget:
            return 4.5
        default:
            return 3
        }
    }
}

private struct PotionBottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let leftLip = rect.minX + rect.width * 0.22
        let rightLip = rect.maxX - rect.width * 0.22
        let leftNeck = rect.minX + rect.width * 0.30
        let rightNeck = rect.maxX - rect.width * 0.30
        let leftBody = rect.minX + rect.width * 0.08
        let rightBody = rect.maxX - rect.width * 0.08
        let top = rect.minY + rect.height * 0.04
        let lipBottom = rect.minY + rect.height * 0.11
        let shoulder = rect.minY + rect.height * 0.22
        let bottomCurve = rect.maxY - rect.height * 0.23
        let bottom = rect.maxY - rect.height * 0.05

        var path = Path()
        path.move(to: CGPoint(x: leftLip, y: top))
        path.addLine(to: CGPoint(x: rightLip, y: top))
        path.addQuadCurve(
            to: CGPoint(x: rightLip + rect.width * 0.08, y: lipBottom),
            control: CGPoint(x: rightLip + rect.width * 0.12, y: top)
        )
        path.addLine(to: CGPoint(x: rightNeck, y: shoulder))
        path.addQuadCurve(
            to: CGPoint(x: rightBody, y: shoulder + rect.height * 0.10),
            control: CGPoint(x: rightBody, y: shoulder)
        )
        path.addLine(to: CGPoint(x: rightBody, y: bottomCurve))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: bottom),
            control: CGPoint(x: rightBody, y: bottom + rect.height * 0.05)
        )
        path.addQuadCurve(
            to: CGPoint(x: leftBody, y: bottomCurve),
            control: CGPoint(x: leftBody, y: bottom + rect.height * 0.05)
        )
        path.addLine(to: CGPoint(x: leftBody, y: shoulder + rect.height * 0.10))
        path.addQuadCurve(
            to: CGPoint(x: leftNeck, y: shoulder),
            control: CGPoint(x: leftBody, y: shoulder)
        )
        path.addLine(to: CGPoint(x: leftLip - rect.width * 0.08, y: lipBottom))
        path.addQuadCurve(
            to: CGPoint(x: leftLip, y: top),
            control: CGPoint(x: leftLip - rect.width * 0.12, y: top)
        )
        path.closeSubpath()
        return path
    }
}

private struct PotionFlaskLiquidShape: Shape {
    func path(in rect: CGRect) -> Path {
        let left = rect.minX + rect.width * 0.06
        let right = rect.maxX - rect.width * 0.06
        let top = rect.minY
        let bottomCurve = rect.maxY - rect.height * 0.20
        let bottom = rect.maxY

        var path = Path()
        path.move(to: CGPoint(x: left, y: top))
        path.addLine(to: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottomCurve))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: bottom),
            control: CGPoint(x: right, y: bottom + rect.height * 0.04)
        )
        path.addQuadCurve(
            to: CGPoint(x: left, y: bottomCurve),
            control: CGPoint(x: left, y: bottom + rect.height * 0.04)
        )
        path.closeSubpath()
        return path
    }
}

private struct BonusLockedFlaskOverlay: View {
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            PotionBottleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            GameColor.controlSurface.opacity(0.10),
                            GameColor.bonusFlaskWash.opacity(0.24),
                            GameColor.controlSurface.opacity(0.26)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            softUnlockHint

            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.bonusFlaskGlow.opacity(0.82))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: 13, y: 18)

            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.controlAccent)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(GameColor.controlSurface.opacity(0.72))
                )
                .overlay(
                    Circle()
                        .stroke(GameColor.bonusFlaskGlow.opacity(0.58), lineWidth: 1.5)
                )
                .shadow(color: GameColor.bonusFlaskGlow.opacity(0.16), radius: 8, x: 0, y: 4)

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.controlSurface)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(GameColor.bonusFlaskGlow)
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.78), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.20), radius: 5, x: 0, y: 3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 1, y: -13)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var softUnlockHint: some View {
        if reduceMotion {
            unlockRing(phase: 0.32)
        } else {
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.2) / 2.2
                unlockRing(phase: phase)
            }
        }
    }

    private func unlockRing(phase: TimeInterval) -> some View {
        let progress = CGFloat(phase)

        return Circle()
            .stroke(GameColor.bonusFlaskGlow.opacity(0.30 - progress * 0.12), lineWidth: 2)
            .frame(width: 46 + progress * 10, height: 46 + progress * 10)
            .blur(radius: 0.3)
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
