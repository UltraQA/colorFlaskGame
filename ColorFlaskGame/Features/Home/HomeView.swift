import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: HomeViewModel
    @State private var bonusSheetHeight: CGFloat = 260
    private let onReturnToMenu: () -> Void
    private let layout = HomeLayout()

    init(viewModel: HomeViewModel, onReturnToMenu: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onReturnToMenu = onReturnToMenu
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutScale = layout.scale(in: proxy.size)

            ZStack {
                gameBackground(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    .zIndex(GameLayer.background)

                BoardVignetteView(scale: layoutScale)
                    .position(boardVignetteCenter(in: proxy.size))
                    .blur(radius: gameSurfaceBlurRadius)
                    .opacity(gameSurfaceOpacity)
                    .zIndex(GameLayer.background + 1)

                ForEach(Array(viewModel.gameManager.flasks.enumerated()), id: \.element.id) { index, flask in
                    Button {
                        viewModel.handleFlaskTap(at: index)
                    } label: {
                        FlaskTubeView(
                            flask: flask,
                            flaskIndex: index,
                            visualState: flaskVisualState(for: flask, at: index)
                        )
                        .scaleEffect(layoutScale)
                        .frame(
                            width: GameMetric.flaskHitWidth * layoutScale,
                            height: GameMetric.flaskHitHeight * layoutScale
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFlaskTappable(flask))
                    .modifier(
                        InvalidMoveShakeEffect(
                            shakes: !reduceMotion && viewModel.invalidFlaskIndices.contains(index)
                                ? CGFloat(viewModel.invalidMoveCount)
                                : 0
                        )
                    )
                    .blur(radius: gameSurfaceBlurRadius)
                    .opacity(gameSurfaceOpacity)
                    .position(layout.flaskCenter(for: index, in: proxy.size, scale: layoutScale))
                    .zIndex(GameLayer.board)
                }

                topControls(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets, scale: layoutScale)
                    .blur(radius: gameSurfaceBlurRadius)
                    .opacity(gameSurfaceOpacity)
                    .allowsHitTesting(viewModel.completionPhase.isPlaying)
                    .zIndex(GameLayer.controls)

                bottomControls(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets, scale: layoutScale)
                    .blur(radius: gameSurfaceBlurRadius)
                    .opacity(gameSurfaceOpacity)
                    .allowsHitTesting(viewModel.completionPhase.isPlaying)
                    .zIndex(GameLayer.controls)

                if viewModel.isOrderBannerVisible && viewModel.completionPhase.isPlaying {
                    OrderBannerView(
                        title: viewModel.orderTitle,
                        subtitle: viewModel.orderSubtitle,
                        scale: layoutScale
                    )
                    .position(orderBannerCenter(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets, scale: layoutScale))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    .zIndex(GameLayer.controls + 1)
                }

                if viewModel.isTutorialPromptVisible && viewModel.completionPhase.isPlaying {
                    TutorialPromptView(
                        title: viewModel.tutorialTitle,
                        subtitle: viewModel.tutorialSubtitle,
                        scale: layoutScale
                    )
                    .position(tutorialPromptCenter(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets, scale: layoutScale))
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(GameLayer.controls + 1)
                }

                if let animation = viewModel.pourAnimation {
                    PourStreamView(
                        from: layout.pourStartPoint(for: animation.sourceIndex, in: proxy.size, scale: layoutScale),
                        to: layout.pourEndPoint(for: animation.targetIndex, in: proxy.size, scale: layoutScale),
                        color: animation.color.swiftUIColor,
                        scale: layoutScale,
                        reduceMotion: reduceMotion
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(GameLayer.animation)
                }

                if viewModel.completionPhase.showsSparkles {
                    WinCelebrationView(reduceMotion: reduceMotion)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
                        .zIndex(GameLayer.celebration)
                }

                if viewModel.completionPhase.showsMessageOverlay, let victoryMessage = viewModel.victoryMessage {
                    WinInterludeOverlay(
                        message: victoryMessage,
                        moveCount: viewModel.lastCompletedMoveCount,
                        herbsReward: viewModel.lastHerbsReward,
                        reduceMotion: reduceMotion
                    ) {
                        viewModel.skipCompletionInterlude()
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(GameLayer.celebration + 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.22), value: viewModel.completionPhase)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $viewModel.bonusUnlockPrompt) { _ in
            BonusUnlockSheet(
                isUnlockingForRound: viewModel.isRewardedBonusUnlockInProgress,
                onUnlockForRound: {
                    viewModel.requestBonusFlaskUnlockForCurrentRound()
                },
                onUnlockForever: {
                    viewModel.unlockBonusFlaskPermanently()
                }
            )
            .readHeight { height in
                bonusSheetHeight = min(max(height, 244), 420)
            }
            .presentationDetents([.height(bonusSheetHeight)])
            .presentationDragIndicator(.visible)
        }
        .alert("Reset order?", isPresented: isResetConfirmationPresented) {
            Button("Keep Playing", role: .cancel) {
                viewModel.cancelReset()
            }

            Button("Reset", role: .destructive) {
                viewModel.confirmReset()
            }
        } message: {
            Text("Your current potion progress will be cleared.")
        }
    }

    private var isResetConfirmationPresented: Binding<Bool> {
        Binding(
            get: {
                viewModel.resetConfirmationPrompt != nil
            },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelReset()
                }
            }
        )
    }

    private var gameSurfaceBlurRadius: CGFloat {
        guard !reduceMotion, viewModel.completionPhase.showsMessageOverlay else { return 0 }
        return 6
    }

    private var gameSurfaceOpacity: Double {
        switch viewModel.completionPhase {
        case .playing, .resolvingWin:
            return 1
        case .celebrating:
            return 0.78
        case .transitioningToNextLevel:
            return 0.62
        }
    }

    private func gameBackground(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        return ZStack {
            GameColor.potionBackground
                .ignoresSafeArea()

            Image("GameBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.92)
        }
        .frame(
            width: size.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: size.height + safeAreaInsets.top + safeAreaInsets.bottom
        )
        .clipped()
        .ignoresSafeArea()
    }

    private func resetButton(scale: CGFloat, isEnabled: Bool) -> some View {
        Button {
            viewModel.requestReset()
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
            .scaleEffect(scale)
            .frame(
                width: GameMetric.resetButtonWidth * scale,
                height: GameMetric.resetButtonHeight * scale
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Reset")
    }

    private func topControls(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> some View {
        let scaledIconSize = GameMetric.iconButtonSize * scale
        let controlCenterY = safeAreaInsets.top + GameMetric.topControlInset * scale + scaledIconSize / 2

        return ZStack {
            LevelBadge(levelNumber: viewModel.currentLevelNumber, herbsBalance: viewModel.herbsBalance)
                .scaleEffect(scale)
                .frame(width: 128 * scale, height: 36 * scale)
                .position(
                    x: size.width / 2,
                    y: controlCenterY
                )

            if let objectiveSummary = viewModel.orderObjectiveSummary {
                OrderObjectiveBadge(summary: objectiveSummary)
                    .scaleEffect(scale)
                    .frame(width: 226 * scale, height: 44 * scale)
                    .position(
                        x: size.width / 2,
                        y: controlCenterY + 48 * scale
                    )
            }

            GameIconButton(
                systemName: "house.fill",
                title: "Menu",
                style: .muted,
                isEnabled: viewModel.canInteractWithBoard
            ) {
                onReturnToMenu()
            }
                .scaleEffect(scale)
                .frame(width: scaledIconSize, height: scaledIconSize)
                .position(
                    x: GameMetric.horizontalInset * scale + scaledIconSize / 2,
                    y: controlCenterY
                )
                .accessibilityLabel("Menu")

            GameIconButton(
                systemName: "arrow.uturn.backward",
                title: "Undo",
                style: .muted,
                isEnabled: viewModel.canUndo
            ) {
                viewModel.undo()
            }
                .scaleEffect(scale)
                .frame(width: scaledIconSize, height: scaledIconSize)
                .position(
                    x: size.width - GameMetric.horizontalInset * scale - scaledIconSize / 2,
                    y: controlCenterY
                )
                .accessibilityLabel("Undo")
        }
    }

    private func orderBannerCenter(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> CGPoint {
        let scaledIconSize = GameMetric.iconButtonSize * scale
        let topControlCenterY = safeAreaInsets.top + GameMetric.orderBannerTopInset * scale + scaledIconSize / 2
        let objectiveOffset: CGFloat = viewModel.orderObjectiveSummary == nil ? 0 : 46 * scale
        return CGPoint(
            x: size.width / 2,
            y: topControlCenterY + 52 * scale + objectiveOffset
        )
    }

    private func tutorialPromptCenter(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> CGPoint {
        let bottomControlCenterY = layout.bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets, scale: scale)
        let bottomDockTopEdge = bottomControlCenterY - GameMetric.bottomControlDockHeight * scale / 2
        let promptHeight: CGFloat = GameMetric.tutorialPromptHeight * scale
        return CGPoint(
            x: size.width / 2,
            y: bottomDockTopEdge - GameMetric.tutorialPromptBottomGap * scale - promptHeight / 2
        )
    }

    private func boardVignetteCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height * GameMetric.boardVerticalCenterRatio)
    }

    private func bottomControls(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> some View {
        let controlCenterY = layout.bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets, scale: scale)
        let dockWidth = min(GameMetric.bottomControlDockWidth, (size.width - GameMetric.horizontalInset * 2 * scale) / scale)

        return BottomControlDock(
            width: dockWidth,
            resetButton: resetButton(scale: 1, isEnabled: viewModel.canInteractWithBoard),
            isHintEnabled: viewModel.canShowHint,
            hintBadgeText: viewModel.hintBadgeText
        ) {
            viewModel.showHint()
        }
        .scaleEffect(scale)
        .frame(width: dockWidth * scale, height: GameMetric.bottomControlDockHeight * scale)
        .position(x: size.width / 2, y: controlCenterY)
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

        if activeGuidanceMove?.sourceIndex == index {
            return .hintSource
        }

        if activeGuidanceMove?.targetIndex == index {
            return .hintTarget
        }

        if flask.isSolved && !flask.isEmpty {
            return .completed
        }

        return flask.isEmpty ? .empty : .normal
    }

    private var activeGuidanceMove: HintMove? {
        viewModel.hintMove ?? viewModel.tutorialMove
    }

    private func isFlaskTappable(_ flask: Flask) -> Bool {
        guard viewModel.canInteractWithBoard else { return false }
        return flask.isPlayable || flask.isBonus
    }

}

private struct LevelBadge: View {
    let levelNumber: Int
    let herbsBalance: Int

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Text("Level \(levelNumber)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Rectangle()
                .fill(GameColor.glassStroke.opacity(0.28))
                .frame(width: 1, height: 16)

            HStack(spacing: 3) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(GameColor.successAccent)

                Text("\(herbsBalance)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 128, height: 36)
        .background {
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.84))
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 6)
        .accessibilityLabel("Level \(levelNumber), \(herbsBalance) herbs")
    }
}

private struct BoardVignetteView: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            GameColor.controlSurface.opacity(0.18),
                            GameColor.controlSurface.opacity(0.24),
                            GameColor.controlSurface.opacity(0.18),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.07),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blendMode(.screen)
        }
        .mask(
            LinearGradient(
                colors: [
                    .clear,
                    .white,
                    .white,
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(width: GameMetric.baseBoardWidth * scale, height: 560 * scale)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct OrderObjectiveBadge: View {
    let summary: OrderObjectiveSummary

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Circle()
                .fill(summary.targetColor.swiftUIColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.58), lineWidth: 2)
                )
                .shadow(color: summary.targetColor.swiftUIColor.opacity(0.34), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(summary.potionName)
                    .font(DSTypography.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Target potion")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(GameColor.glassStroke.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: DSSpacing.xs)

            Text(summary.progressText)
                .font(DSTypography.headline)
                .foregroundStyle(GameColor.controlSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, DSSpacing.sm)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(GameColor.controlAccent)
                )
        }
        .padding(.leading, DSSpacing.sm)
        .padding(.trailing, DSSpacing.xs)
        .frame(width: 226, height: 44)
        .background(
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.84))
                .overlay(
                    Capsule()
                        .stroke(GameColor.glassStroke.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.potionName). Target \(summary.targetColor.accessibilityName). Progress \(summary.progressText).")
    }
}

private struct OrderBannerView: View {
    let title: String
    let subtitle: String
    let scale: CGFloat

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "flask.fill")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.controlAccent)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(GameColor.controlSurface.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DSTypography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(GameColor.glassStroke.opacity(0.78))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, 6)
        .frame(width: GameMetric.orderBannerWidth, alignment: .leading)
        .background(
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.84))
                .overlay(
                    Capsule()
                        .stroke(GameColor.controlAccent.opacity(0.34), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 8)
        .scaleEffect(scale)
        .frame(width: GameMetric.orderBannerWidth * scale, height: 46 * scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
    }
}

private struct TutorialPromptView: View {
    let title: String
    let subtitle: String
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(GameColor.controlAccent)

                Text(title)
                    .font(DSTypography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(subtitle)
                .font(DSTypography.caption)
                .foregroundStyle(GameColor.glassStroke.opacity(0.82))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .frame(width: GameMetric.tutorialPromptWidth, height: GameMetric.tutorialPromptHeight, alignment: .center)
        .background(
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.86))
                .overlay(
                    Capsule()
                        .stroke(GameColor.glassStroke.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.26), radius: 14, x: 0, y: 9)
        .scaleEffect(scale)
        .frame(width: GameMetric.tutorialPromptWidth * scale, height: GameMetric.tutorialPromptHeight * scale)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
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
    let isUnlockingForRound: Bool
    let onUnlockForRound: () -> Void
    let onUnlockForever: () -> Void

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Capsule()
                .fill(GameColor.controlAccent.opacity(0.26))
                .frame(width: 64, height: 6)

            VStack(spacing: DSSpacing.xs) {
                Text("Open extra flask")
                    .font(DSTypography.title)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Add one empty flask when this order needs more room.")
                    .font(DSTypography.caption)
                    .foregroundStyle(GameColor.glassStroke.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            BonusFlaskPreview()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DSSpacing.lg) {
                    unlockActions
                }

                VStack(spacing: DSSpacing.md) {
                    unlockActions
                }
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.top, DSSpacing.lg)
        .padding(.bottom, DSSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(GameColor.potionBackground)
    }

    @ViewBuilder
    private var unlockActions: some View {
        unlockAction(
            systemName: "play.circle.fill",
            title: isUnlockingForRound ? "Opening..." : "This order",
            subtitle: "Watch ad",
            footnote: "Temporary help",
            isEnabled: !isUnlockingForRound,
            action: onUnlockForRound
        )

        unlockAction(
            systemName: "sparkles",
            title: "Always available",
            subtitle: "Future purchase",
            footnote: "Design stub",
            isEnabled: !isUnlockingForRound,
            action: onUnlockForever
        )
    }

    private func unlockAction(
        systemName: String,
        title: String,
        subtitle: String,
        footnote: String,
        isEnabled: Bool,
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(subtitle)
                        .font(DSTypography.caption)
                        .foregroundStyle(GameColor.glassStroke.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(footnote)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(GameColor.glassStroke.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

private struct BonusFlaskPreview: View {
    var body: some View {
        HStack(spacing: DSSpacing.md) {
            previewFlask(isLocked: true)

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(GameColor.controlAccent)

            previewFlask(isLocked: false)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .background(
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.46))
                .overlay(
                    Capsule()
                        .stroke(GameColor.glassStroke.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked extra flask becomes available.")
    }

    private func previewFlask(isLocked: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    isLocked ? GameColor.lockedStroke : GameColor.successAccent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: isLocked ? [4, 4] : [])
                )
                .frame(width: 32, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(GameColor.glassFill.opacity(isLocked ? 0.3 : 0.72))
                )

            Image(systemName: isLocked ? "lock.fill" : "checkmark")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(isLocked ? GameColor.glassStroke.opacity(0.72) : GameColor.controlSurface)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(isLocked ? GameColor.controlSurface.opacity(0.72) : GameColor.successAccent)
                )
                .offset(y: 8)
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self, perform: onChange)
    }
}

private struct BottomControlDock<ResetButton: View>: View {
    let width: CGFloat
    let resetButton: ResetButton
    let isHintEnabled: Bool
    let hintBadgeText: String
    let onHint: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            resetButton
                .frame(width: GameMetric.resetButtonWidth, height: GameMetric.resetButtonHeight)

            Spacer(minLength: DSSpacing.md)

            GameIconButton(
                systemName: "lightbulb.fill",
                title: "Hint",
                style: .accent,
                isEnabled: isHintEnabled,
                action: onHint
            )
            .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
            .overlay(alignment: .topTrailing) {
                HintCostBadge(text: hintBadgeText, isEnabled: isHintEnabled)
                    .offset(x: 6, y: -2)
            }
            .accessibilityLabel("Hint")
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(width: width, height: GameMetric.bottomControlDockHeight)
        .background {
            Capsule()
                .fill(GameColor.controlSurface.opacity(0.46))
                .overlay(
                    Capsule()
                        .stroke(GameColor.glassStroke.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HintCostBadge: View {
    let text: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .black, design: .rounded))

            Text(text)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(GameColor.controlSurface)
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(
            Capsule()
                .fill(isEnabled ? GameColor.successAccent : GameColor.controlMuted)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
        )
        .opacity(isEnabled ? 1 : 0.7)
        .accessibilityHidden(true)
    }

    private var systemImage: String {
        switch text {
        case "Free":
            return "sparkles"
        case "Ad":
            return "play.rectangle.fill"
        default:
            return "leaf.fill"
        }
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
        .opacity(isEnabled ? 1 : 0.52)
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
            return GameColor.controlSurface
        case .muted:
            return GameColor.glassStroke
        }
    }

    private var borderColor: Color {
        switch style {
        case .accent:
            return Color.white.opacity(0.38)
        case .muted:
            return Color.white.opacity(0.18)
        }
    }
}

private struct WinCelebrationView: View {
    let reduceMotion: Bool

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
            if reduceMotion {
                sparkleCanvas(time: 0, in: proxy.size, isStatic: true)
            } else {
                TimelineView(.animation) { timeline in
                    sparkleCanvas(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        in: proxy.size,
                        isStatic: false
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func sparkleCanvas(time: TimeInterval, in size: CGSize, isStatic: Bool) -> some View {
        Canvas { context, canvasSize in
            for sparkle in sparkles {
                let phase = isStatic ? 0 : (time + sparkle.delay).truncatingRemainder(dividingBy: 1.1) / 1.1
                let opacity = isStatic ? 0.72 : max(0, 1 - phase)
                let radius = sparkle.size * (isStatic ? 1.2 : 0.8 + phase * 1.8)
                let center = CGPoint(
                    x: canvasSize.width * sparkle.x,
                    y: canvasSize.height * sparkle.y - (isStatic ? 0 : phase * 34)
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
        .frame(width: size.width, height: size.height)
    }

    private struct Sparkle {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let delay: TimeInterval
    }
}

private struct WinInterludeOverlay: View {
    let message: String
    let moveCount: Int?
    let herbsReward: Int?
    let reduceMotion: Bool
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            GameColor.controlSurface
                .opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: DSSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(GameColor.controlAccent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(GameColor.controlSurface.opacity(0.8))
                            .overlay(
                                Circle()
                                    .stroke(GameColor.controlAccent.opacity(0.58), lineWidth: 2)
                            )
                    )

                Text(message)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.vertical, DSSpacing.sm)
                    .background(
                        Capsule()
                            .fill(GameColor.controlSurface.opacity(0.84))
                            .overlay(
                                Capsule()
                                    .stroke(GameColor.controlAccent.opacity(0.72), lineWidth: 2)
                            )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)

                Text("Next potion brewing...")
                    .font(DSTypography.caption)
                    .foregroundStyle(GameColor.glassStroke.opacity(0.78))

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DSSpacing.sm) {
                        winStats
                    }

                    VStack(spacing: DSSpacing.xs) {
                        winStats
                    }
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            .scaleEffect(reduceMotion ? 1 : 1.02)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSkip)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [message]

        if let moveCount {
            parts.append("Completed in \(moveCount) moves")
        }

        if let herbsReward {
            parts.append("Earned \(herbsReward) herbs")
        }

        parts.append("Next potion brewing")
        return parts.joined(separator: ". ")
    }

    @ViewBuilder
    private var winStats: some View {
        if let moveCount {
            WinStatPill(
                systemName: "arrow.triangle.2.circlepath",
                title: "\(moveCount) moves",
                surfaceColor: GameColor.controlSurface,
                foregroundColor: GameColor.glassStroke
            )
        }

        if let herbsReward {
            WinStatPill(
                systemName: "leaf.fill",
                title: "+\(herbsReward) herbs",
                surfaceColor: GameColor.successAccent,
                foregroundColor: GameColor.controlSurface
            )
        }
    }
}

private struct WinStatPill: View {
    let systemName: String
    let title: String
    let surfaceColor: Color
    let foregroundColor: Color

    var body: some View {
        Label(title, systemImage: systemName)
            .font(DSTypography.headline)
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
            .background(
                Capsule()
                    .fill(surfaceColor)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.36), lineWidth: 1)
                    )
            )
            .shadow(color: surfaceColor.opacity(0.24), radius: 12, x: 0, y: 8)
    }
}
