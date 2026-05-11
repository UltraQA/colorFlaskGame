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
    let flask: Flask
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
        }
        .frame(width: GameMetric.flaskWidth, height: GameMetric.flaskHeight)
        .offset(y: visualState == .selected ? -14 : 0)
        .shadow(
            color: shadowColor,
            radius: visualState == .selected ? 18 : 12,
            x: 0,
            y: visualState == .selected ? 12 : 10
        )
        .animation(.snappy(duration: 0.2), value: visualState)
        .frame(width: GameMetric.flaskHitWidth, height: GameMetric.flaskHitHeight)
        .accessibilityLabel("Flask")
        .accessibilityValue(accessibilityValue)
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

    private var accessibilityValue: String {
        if !flask.isPlayable {
            return "Locked bonus flask"
        }

        switch visualState {
        case .selected:
            return "Selected"
        case .invalidTarget:
            return "Invalid target"
        case .hintSource:
            return "Hint source"
        case .hintTarget:
            return "Hint target"
        case .completed:
            return "Completed"
        case .empty:
            return "Empty"
        case .normal, .lockedBonus:
            return "Not selected"
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
