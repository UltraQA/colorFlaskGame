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
                            visualState: flaskVisualState(for: flask, at: index)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFlaskTappable(flask))
                    .modifier(
                        InvalidMoveShakeEffect(
                            shakes: viewModel.invalidFlaskIndices.contains(index) ? CGFloat(viewModel.invalidMoveCount) : 0
                        )
                    )
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

                if viewModel.roundState == .completing {
                    WinCelebrationView()
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(GameLayer.celebration)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $viewModel.bonusUnlockPrompt) { _ in
            BonusUnlockSheet(
                onUnlockForRound: {
                    viewModel.unlockBonusFlaskForCurrentRound()
                },
                onUnlockForever: {
                    viewModel.unlockBonusFlaskPermanently()
                }
            )
            .presentationDetents([.height(244)])
            .presentationDragIndicator(.visible)
        }
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
        GameIconButton(
            systemName: "arrow.uturn.backward",
            title: "Undo",
            style: .muted,
            isEnabled: viewModel.canUndo
        ) {
            viewModel.undo()
        }
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

            GameIconButton(
                systemName: "lightbulb.fill",
                title: "Hint",
                style: .accent,
                isEnabled: viewModel.canShowHint
            ) {
                viewModel.showHint()
            }
                .position(
                    x: size.width - GameMetric.horizontalInset - GameMetric.iconButtonSize / 2,
                    y: bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets)
                )
                .accessibilityLabel("Hint")
        }
    }

    private func flaskVisualState(for flask: Flask, at index: Int) -> FlaskVisualState {
        if !flask.isPlayable {
            return .lockedBonus
        }

        if viewModel.selectedFlaskIndex == index {
            return .selected
        }

        if viewModel.invalidFlaskIndices.contains(index) {
            return .invalidTarget
        }

        if viewModel.hintMove?.sourceIndex == index {
            return .hintSource
        }

        if viewModel.hintMove?.targetIndex == index {
            return .hintTarget
        }

        if flask.isSolved && !flask.isEmpty {
            return .completed
        }

        return flask.isEmpty ? .empty : .normal
    }

    private func isFlaskTappable(_ flask: Flask) -> Bool {
        guard viewModel.canInteractWithBoard else { return false }
        return flask.isPlayable || flask.isBonus
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

private struct InvalidMoveShakeEffect: GeometryEffect {
    var shakes: CGFloat
    private let amplitude: CGFloat = 7
    private let oscillations: CGFloat = 4

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translationX = sin(shakes * .pi * oscillations) * amplitude
        return ProjectionTransform(CGAffineTransform(translationX: translationX, y: 0))
    }
}

private struct BonusUnlockSheet: View {
    let onUnlockForRound: () -> Void
    let onUnlockForever: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Capsule()
                .fill(GameColor.controlAccent.opacity(0.26))
                .frame(width: 64, height: 6)

            HStack(spacing: DSSpacing.lg) {
                unlockAction(
                    systemName: "play.rectangle.fill",
                    title: "Ad",
                    subtitle: "This round",
                    action: onUnlockForRound
                )

                unlockAction(
                    systemName: "sparkles",
                    title: "Forever",
                    subtitle: "Always open",
                    action: onUnlockForever
                )
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.top, DSSpacing.lg)
        .padding(.bottom, DSSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameColor.potionBackground)
    }

    private func unlockAction(
        systemName: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: DSSpacing.sm) {
                Image(systemName: systemName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
                    .background(
                        Circle()
                            .fill(GameColor.controlAccent)
                    )

                VStack(spacing: DSSpacing.xxs) {
                    Text(title)
                        .font(DSTypography.headline)
                        .foregroundStyle(GameColor.glassStroke)

                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(GameColor.glassStroke.opacity(0.68))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(GameColor.controlSurface.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .stroke(GameColor.glassStroke.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
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
    var isEnabled = true
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.36)
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

private struct WinCelebrationView: View {
    private let sparkles: [Sparkle] = [
        Sparkle(x: 0.18, y: 0.26, size: 10, delay: 0.0),
        Sparkle(x: 0.34, y: 0.18, size: 7, delay: 0.18),
        Sparkle(x: 0.68, y: 0.22, size: 11, delay: 0.06),
        Sparkle(x: 0.82, y: 0.34, size: 8, delay: 0.24),
        Sparkle(x: 0.26, y: 0.66, size: 9, delay: 0.12),
        Sparkle(x: 0.74, y: 0.64, size: 10, delay: 0.3),
        Sparkle(x: 0.50, y: 0.46, size: 12, delay: 0.16)
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    for sparkle in sparkles {
                        let phase = (time + sparkle.delay).truncatingRemainder(dividingBy: 1.1) / 1.1
                        let opacity = max(0, 1 - phase)
                        let radius = sparkle.size * (0.8 + phase * 1.8)
                        let center = CGPoint(
                            x: size.width * sparkle.x,
                            y: size.height * sparkle.y - phase * 34
                        )

                        var path = Path()
                        path.addEllipse(
                            in: CGRect(
                                x: center.x - radius / 2,
                                y: center.y - radius / 2,
                                width: radius,
                                height: radius
                            )
                        )

                        context.fill(
                            path,
                            with: .color(GameColor.controlAccent.opacity(opacity * 0.9))
                        )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private struct Sparkle {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let delay: TimeInterval
    }
}
