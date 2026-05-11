import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let columns = 4

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                gameBackground(in: proxy.size)
                    .zIndex(GameLayer.background)

                ForEach(Array(viewModel.gameManager.flasks.enumerated()), id: \.element.id) { index, flask in
                    Button {
                        viewModel.handleFlaskTap(at: index)
                    } label: {
                        FlaskTubeView(
                            flask: flask,
                            isSelected: viewModel.selectedFlaskIndex == index
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!flask.isPlayable)
                    .position(flaskCenter(for: index, in: proxy.size))
                    .zIndex(GameLayer.board)
                }

                topControls(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    .zIndex(GameLayer.controls)

                bottomControls(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    .zIndex(GameLayer.controls)

                if let animation = viewModel.pourAnimation {
                    PourStreamView(
                        from: pourStartPoint(for: animation.sourceIndex, in: proxy.size),
                        to: pourEndPoint(for: animation.targetIndex, in: proxy.size),
                        color: animation.color
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(GameLayer.animation)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func gameBackground(in size: CGSize) -> some View {
        ZStack {
            GameColor.potionBackground

            Image("GameBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.92)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }

    private var resetButton: some View {
        Button {
            viewModel.startNewGame()
        } label: {
            ZStack {
                Text("reset")
                    .font(DSTypography.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .opacity(0)
                    .zIndex(GameLayer.background)

                Image("ResetButton")
                    .resizable()
                    .scaledToFill()
                    .zIndex(GameLayer.controls)
            }
            .frame(width: GameMetric.resetButtonWidth, height: GameMetric.resetButtonHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset")
    }

    private func topControls(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        GameIconButton(systemName: "arrow.uturn.backward", title: "Undo", style: .muted) {}
            .position(
                x: size.width - GameMetric.horizontalInset - GameMetric.iconButtonSize / 2,
                y: safeAreaInsets.top + GameMetric.topControlInset + GameMetric.iconButtonSize / 2
            )
            .accessibilityLabel("Undo")
    }

    private func bottomControls(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        ZStack {
            resetButton
                .position(
                    x: GameMetric.horizontalInset + GameMetric.resetButtonWidth / 2,
                    y: bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets)
                )

            GameIconButton(systemName: "lightbulb.fill", title: "Hint", style: .accent) {}
                .position(
                    x: size.width - GameMetric.horizontalInset - GameMetric.iconButtonSize / 2,
                    y: bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets)
                )
                .accessibilityLabel("Hint")
        }
    }

    private func flaskCenter(for index: Int, in size: CGSize) -> CGPoint {
        let column = index % columns
        let row = index / columns
        let horizontalPadding: CGFloat = 18
        let verticalCenter = size.height * 0.48
        let cellWidth = (size.width - horizontalPadding * 2) / CGFloat(columns)
        let rowSpacing: CGFloat = min(230, size.height * 0.26)

        return CGPoint(
            x: horizontalPadding + cellWidth * (CGFloat(column) + 0.5),
            y: verticalCenter + (CGFloat(row) - 0.5) * rowSpacing
        )
    }

    private func pourStartPoint(for index: Int, in size: CGSize) -> CGPoint {
        let center = flaskCenter(for: index, in: size)
        return CGPoint(x: center.x, y: center.y - 108)
    }

    private func pourEndPoint(for index: Int, in size: CGSize) -> CGPoint {
        let center = flaskCenter(for: index, in: size)
        return CGPoint(x: center.x, y: center.y - 92)
    }

    private func bottomControlCenterY(in size: CGSize, safeAreaInsets: EdgeInsets) -> CGFloat {
        size.height - safeAreaInsets.bottom - GameMetric.bottomControlInset - GameMetric.iconButtonSize / 2
    }
}

private struct GameIconButton: View {
    enum Style {
        case accent
        case muted
    }

    let systemName: String
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(iconColor)
                .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
                .background(
                    Circle()
                        .fill(surfaceColor)
                        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 8)
                )
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var surfaceColor: Color {
        switch style {
        case .accent:
            return GameColor.controlAccent
        case .muted:
            return GameColor.controlSurface.opacity(0.88)
        }
    }

    private var iconColor: Color {
        switch style {
        case .accent:
            return .white
        case .muted:
            return GameColor.glassStroke
        }
    }

    private var borderColor: Color {
        switch style {
        case .accent:
            return Color.white.opacity(0.38)
        case .muted:
            return Color.white.opacity(0.08)
        }
    }
}
