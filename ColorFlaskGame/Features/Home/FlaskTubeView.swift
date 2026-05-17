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

    private var sectionHeight: CGFloat {
        (GameMetric.flaskHeight - GameMetric.liquidBottomInset * 2) / CGFloat(Flask.maxCapacity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 26)
                .fill(flask.isPlayable ? GameColor.glassFill : GameColor.glassFill.opacity(0.42))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(flask.isPlayable ? 0.18 : 0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                )

            liquidStack
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, GameMetric.liquidInset)
                .padding(.bottom, GameMetric.liquidBottomInset)

            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    strokeColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        dash: flask.isPlayable ? [] : [8, 8]
                    )
                )

            RoundedRectangle(cornerRadius: 18)
                .fill(GameColor.glassHighlight)
                .frame(width: 9)
                .padding(.leading, 12)
                .padding(.top, 18)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)

            Capsule()
                .fill(Color.white.opacity(0.52))
                .frame(width: 34, height: 7)
                .padding(.top, 12)
                .padding(.leading, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Circle()
                .fill(Color.white.opacity(0.48))
                .frame(width: 12, height: 12)
                .padding(.top, 11)
                .padding(.leading, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if !flask.isPlayable {
                lockedOverlay
            }

            stateIndicator
        }
        .frame(width: GameMetric.flaskWidth, height: GameMetric.flaskHeight)
        .offset(y: visualState == .selected ? -14 : 0)
        .shadow(
            color: shadowColor,
            radius: visualState == .selected ? 18 : 12,
            x: 0,
            y: visualState == .selected ? 12 : 10
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: visualState)
        .frame(width: GameMetric.flaskHitWidth, height: GameMetric.flaskHitHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Flask \(flaskIndex + 1)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    private var liquidStack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ForEach(Array(flask.colors.reversed().enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.82),
                                color,
                                color.opacity(0.9)
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
            return GameColor.controlAccent.opacity(0.9)
        case .hintSource, .hintTarget:
            return GameColor.controlAccent
        case .normal, .empty, .lockedBonus:
            return GameColor.glassStroke.opacity(0.82)
        }
    }

    private var strokeWidth: CGFloat {
        switch visualState {
        case .selected, .invalidTarget, .hintSource, .hintTarget:
            return 4
        default:
            return 3
        }
    }

    private var shadowColor: Color {
        switch visualState {
        case .selected:
            return GameColor.selectedGlow.opacity(0.34)
        case .invalidTarget:
            return GameColor.invalid.opacity(0.34)
        case .hintSource, .hintTarget:
            return GameColor.controlAccent.opacity(0.32)
        case .completed:
            return GameColor.controlAccent.opacity(0.22)
        default:
            return .black.opacity(0.28)
        }
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
                systemName: "arrow.up",
                foreground: GameColor.controlSurface,
                background: GameColor.controlAccent,
                size: 25
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -9)

        case .hintTarget:
            indicatorSymbol(
                systemName: "arrow.down",
                foreground: GameColor.controlSurface,
                background: GameColor.controlAccent,
                size: 25
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(x: 8, y: -9)

        case .completed:
            indicatorSymbol(
                systemName: "checkmark",
                foreground: GameColor.controlSurface,
                background: GameColor.controlAccent.opacity(0.92),
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
                    .stroke(GameColor.glassStroke.opacity(0.86), lineWidth: 2)
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
            values.append("Top color: \(accessibilityName(for: topColor))")
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
            .map(accessibilityName)
            .joined(separator: ", ")

        return "Contents from bottom: \(colors)"
    }

    private func accessibilityName(for color: Color) -> String {
        switch color {
        case Color.red:
            return "red"
        case Color.green:
            return "green"
        case Color.blue:
            return "blue"
        case Color.yellow:
            return "yellow"
        case Color(red: 1.00, green: 0.32, blue: 0.48):
            return "ruby"
        case Color(red: 0.34, green: 0.88, blue: 0.68):
            return "emerald"
        case Color(red: 1.00, green: 0.78, blue: 0.27):
            return "honey"
        case Color(red: 0.33, green: 0.59, blue: 1.00):
            return "moon blue"
        case Color(red: 0.72, green: 0.43, blue: 1.00):
            return "violet"
        case Color(red: 1.00, green: 0.52, blue: 0.25):
            return "orange"
        case Color(red: 1.00, green: 0.42, blue: 0.77):
            return "rose"
        case Color(red: 0.29, green: 0.91, blue: 0.96):
            return "aqua"
        default:
            return "unknown potion color"
        }
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
