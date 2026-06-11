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
                    let pourPose = flaskPourPose(for: index, in: proxy.size, scale: layoutScale)
                    let flaskHitHeight = flaskHitHeight(for: flask)

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
                            height: flaskHitHeight * layoutScale
                        )
                        .rotationEffect(pourPose.rotation, anchor: .top)
                        .scaleEffect(pourPose.scale)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFlaskEnabled(flask))
                    .allowsHitTesting(isFlaskTappable(flask))
                    .modifier(
                        InvalidMoveShakeEffect(
                            shakes: !reduceMotion && viewModel.invalidFlaskIndices.contains(index)
                                ? CGFloat(viewModel.invalidMoveCount)
                                : 0
                        )
                    )
                    .blur(radius: gameSurfaceBlurRadius)
                    .opacity(gameSurfaceOpacity * flaskFocusOpacity(for: index))
                    .position(pourPose.center)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.28),
                        value: viewModel.pourAnimation
                    )
                    .zIndex(pourPose.zIndex)
                }

                ForEach(viewModel.tutorialMarkers, id: \.flaskIndex) { marker in
                    TutorialFlaskMarkerView(kind: marker.kind, scale: layoutScale)
                        .position(tutorialMarkerCenter(for: marker.flaskIndex, in: proxy.size, scale: layoutScale))
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8)))
                        .zIndex(GameLayer.controls + 2)
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

                if let herbsPrompt = viewModel.herbsTutorialPrompt, viewModel.completionPhase.isPlaying {
                    HerbsTutorialOverlay(
                        herbsAmount: herbsPrompt.herbsAmount,
                        reduceMotion: reduceMotion
                    ) {
                        viewModel.claimHerbsTutorialReward()
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(GameLayer.controls + 4)
                }

                if viewModel.hintPurchasePrompt != nil, viewModel.completionPhase.isPlaying {
                    HintPurchaseOverlay(
                        herbsBalance: viewModel.herbsBalance,
                        herbsCost: HomeViewModel.extraHintHerbsCost,
                        canUseHerbs: viewModel.canPurchaseHintWithHerbs,
                        canWatchAd: viewModel.canPurchaseHintWithRewardedAd,
                        reduceMotion: reduceMotion,
                        onUseHerbs: viewModel.purchaseHintWithHerbs,
                        onWatchAd: viewModel.purchaseHintWithRewardedAd,
                        onCancel: viewModel.dismissHintPurchasePrompt
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(GameLayer.controls + 4)
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
                isUnlockingPermanently: viewModel.isPermanentBonusUnlockInProgress,
                isRewardedUnlockAvailable: viewModel.featureFlags.rewardedAdsEnabled,
                isPermanentUnlockAvailable: viewModel.featureFlags.permanentBonusFlaskPurchaseEnabled,
                onUnlockForRound: {
                    viewModel.requestBonusFlaskUnlockForCurrentRound()
                },
                onUnlockForever: {
                    viewModel.unlockBonusFlaskPermanently()
                }
            )
            .readHeight { height in
                guard height.isFinite, height > 0 else { return }
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

    private func flaskFocusOpacity(for index: Int) -> Double {
        guard let animation = viewModel.pourAnimation else {
            return 1
        }

        return index == animation.sourceIndex || index == animation.targetIndex ? 1 : 0.44
    }

    private func flaskPourPose(for index: Int, in size: CGSize, scale: CGFloat) -> FlaskPourPose {
        let restingCenter = flaskCenter(for: index, in: size, scale: scale)
        guard let animation = viewModel.pourAnimation,
              animation.sourceIndex == index,
              !reduceMotion else {
            return FlaskPourPose(center: restingCenter, rotation: .zero, scale: 1, zIndex: GameLayer.board)
        }

        let targetCenter = flaskCenter(for: animation.targetIndex, in: size, scale: scale)
        let direction: CGFloat = targetCenter.x >= restingCenter.x ? 1 : -1
        let mouthPoint = pouringMouthPoint(
            sourceCenter: restingCenter,
            targetCenter: targetCenter,
            scale: scale
        )
        let liftedCenter = CGPoint(
            x: mouthPoint.x,
            y: mouthPoint.y + GameMetric.flaskHitHeight * scale / 2
        )

        return FlaskPourPose(
            center: liftedCenter,
            rotation: .degrees(direction > 0 ? 62 : -62),
            scale: 1.04,
            zIndex: GameLayer.animation + 1
        )
    }

    private func pouringMouthPoint(sourceCenter: CGPoint, targetCenter: CGPoint, scale: CGFloat) -> CGPoint {
        let direction: CGFloat = targetCenter.x >= sourceCenter.x ? 1 : -1
        let targetOpening = CGPoint(
            x: targetCenter.x,
            y: targetCenter.y - 92 * scale
        )

        return CGPoint(
            x: targetOpening.x - direction * 46 * scale,
            y: targetOpening.y - 16 * scale
        )
    }

    private func gameBackground(in size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        return ZStack {
            GameColor.potionBackground
                .ignoresSafeArea()

            Image("GameBackground")
                .resizable()
                .scaledToFill()
                .saturation(0.52)
                .brightness(-0.16)
                .opacity(0.34)

            CozyPotionShopBackgroundView()
        }
        .frame(
            width: max(1, size.width + safeAreaInsets.leading + safeAreaInsets.trailing),
            height: max(1, size.height + safeAreaInsets.top + safeAreaInsets.bottom)
        )
        .clipped()
        .ignoresSafeArea()
    }

    private func resetButton(scale: CGFloat, isEnabled: Bool) -> some View {
        GameIconButton(
            systemName: "arrow.clockwise",
            title: "Reset",
            style: .muted,
            isEnabled: isEnabled
        ) {
            viewModel.requestReset()
        }
        .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
        .frame(width: GameMetric.resetButtonWidth, height: GameMetric.resetButtonHeight)
        .scaleEffect(scale)
        .frame(
            width: GameMetric.resetButtonWidth * scale,
            height: GameMetric.resetButtonHeight * scale
        )
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
        let availableWidth = (size.width - GameMetric.horizontalInset * 2 * scale) / max(scale, 0.001)
        let dockWidth = max(1, min(GameMetric.bottomControlDockWidth, availableWidth))

        return BottomControlDock(
            width: dockWidth,
            resetButton: resetButton(scale: 1, isEnabled: viewModel.canInteractWithBoard),
            isHintEnabled: viewModel.canShowHint,
            hintBadgeText: viewModel.hintBadgeText,
            isHintAttentionActive: viewModel.shouldPromptHintUse
        ) {
            viewModel.showHint()
        }
        .scaleEffect(scale)
        .frame(width: dockWidth * scale, height: GameMetric.bottomControlDockHeight * scale)
        .position(x: size.width / 2, y: controlCenterY)
    }

    private func flaskCenter(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        layout.flaskCenter(
            for: index,
            totalCount: viewModel.gameManager.flasks.count,
            centersSparseRows: viewModel.centersSparseTutorialRows,
            in: size,
            scale: scale
        )
    }

    private func tutorialMarkerCenter(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        let center = flaskCenter(for: index, in: size, scale: scale)
        let flask = viewModel.gameManager.flasks[index]
        return CGPoint(x: center.x, y: center.y - flaskHitHeight(for: flask) * scale * 0.48)
    }

    private func flaskHitHeight(for flask: Flask) -> CGFloat {
        GameMetric.flaskHitHeight + CGFloat(max(0, flask.capacity - Flask.maxCapacity)) * 12
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
        guard viewModel.tutorialMarkers.isEmpty else { return nil }
        return viewModel.hintMove ?? viewModel.tutorialMove
    }

    private func isFlaskTappable(_ flask: Flask) -> Bool {
        guard viewModel.canInteractWithBoard else { return false }
        return isFlaskEnabled(flask)
    }

    private func isFlaskEnabled(_ flask: Flask) -> Bool {
        flask.isPlayable || flask.isBonus
    }

}

private struct FlaskPourPose {
    let center: CGPoint
    let rotation: Angle
    let scale: CGFloat
    let zIndex: Double
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

private struct TutorialFlaskMarkerView: View {
    let kind: TutorialMarkerKind
    let scale: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 25 * scale, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 42 * scale, height: 42 * scale)
            .background(
                Circle()
                    .fill(fillColor)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.72), lineWidth: 2 * scale)
                    )
            )
            .shadow(color: fillColor.opacity(0.36), radius: 10 * scale, x: 0, y: 5 * scale)
            .accessibilityLabel(accessibilityLabel)
    }

    private var systemImage: String {
        switch kind {
        case .correctTarget:
            return "checkmark"
        case .blockedTarget:
            return "xmark"
        }
    }

    private var fillColor: Color {
        switch kind {
        case .correctTarget:
            return GameColor.successAccent
        case .blockedTarget:
            return GameColor.errorAccent
        }
    }

    private var accessibilityLabel: String {
        switch kind {
        case .correctTarget:
            return "Correct flask"
        case .blockedTarget:
            return "Blocked flask"
        }
    }
}

private struct CozyPotionShopBackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.07, blue: 0.15),
                        Color(red: 0.18, green: 0.10, blue: 0.18),
                        Color(red: 0.08, green: 0.12, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: size.height * 0.085) {
                    PotionShelf(width: size.width * 0.78, bottleScale: 0.82)
                        .opacity(0.52)

                    Spacer(minLength: size.height * 0.34)

                    PotionShelf(width: size.width * 0.68, bottleScale: 0.68)
                        .opacity(0.34)
                }
                .padding(.top, size.height * 0.17)
                .padding(.bottom, size.height * 0.16)

                WindowGlow()
                    .frame(width: size.width * 0.34, height: size.height * 0.28)
                    .position(x: size.width * 0.82, y: size.height * 0.25)
                    .opacity(0.28)

                CounterSilhouette()
                    .frame(width: size.width * 1.08, height: size.height * 0.22)
                    .position(x: size.width / 2, y: size.height * 0.91)

                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .clear,
                                GameColor.potionBackground.opacity(0.32),
                                GameColor.potionBackground.opacity(0.72)
                            ],
                            center: .center,
                            startRadius: min(size.width, size.height) * 0.18,
                            endRadius: max(size.width, size.height) * 0.64
                        )
                    )

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .black.opacity(0.18),
                                .clear,
                                .clear,
                                .black.opacity(0.36)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PotionShelf: View {
    let width: CGFloat
    let bottleScale: CGFloat

    private let bottleColors: [Color] = [
        Color(red: 0.34, green: 0.93, blue: 0.66),
        Color(red: 1.00, green: 0.72, blue: 0.25),
        Color(red: 0.72, green: 0.43, blue: 1.00),
        Color(red: 0.29, green: 0.91, blue: 0.96),
        Color(red: 1.00, green: 0.42, blue: 0.77)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 16 * bottleScale) {
                ForEach(Array(bottleColors.enumerated()), id: \.offset) { index, color in
                    ShelfBottle(color: color, height: bottleHeight(at: index) * bottleScale)
                }
            }
            .padding(.bottom, 4)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.41, green: 0.26, blue: 0.19),
                            Color(red: 0.23, green: 0.13, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 10)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.34), radius: 14, x: 0, y: 8)
        }
    }

    private func bottleHeight(at index: Int) -> CGFloat {
        [44, 58, 50, 64, 48][index]
    }
}

private struct ShelfBottle: View {
    let color: Color
    let height: CGFloat

    var body: some View {
        VStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 3)
                .fill(GameColor.glassStroke.opacity(0.34))
                .frame(width: height * 0.22, height: height * 0.18)

            RoundedRectangle(cornerRadius: height * 0.14)
                .fill(color.opacity(0.58))
                .frame(width: height * 0.42, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: height * 0.14)
                        .stroke(GameColor.glassStroke.opacity(0.38), lineWidth: 1.5)
                )
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(.white.opacity(0.24))
                        .frame(width: height * 0.09, height: height * 0.58)
                        .padding(.leading, height * 0.08)
                        .padding(.top, height * 0.12)
                }
        }
        .shadow(color: color.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}

private struct WindowGlow: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.74, blue: 0.82).opacity(0.44),
                        Color(red: 0.98, green: 0.82, blue: 0.48).opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.16), lineWidth: 2)
            )
            .shadow(color: Color(red: 0.29, green: 0.91, blue: 0.96).opacity(0.18), radius: 28)
    }
}

private struct CounterSilhouette: View {
    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.44, green: 0.28, blue: 0.19).opacity(0.9))
                .frame(height: 18)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.15, blue: 0.14).opacity(0.94),
                            Color(red: 0.08, green: 0.06, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: .black.opacity(0.34), radius: 22, x: 0, y: -8)
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

private struct HerbsTutorialOverlay: View {
    let herbsAmount: Int
    let reduceMotion: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            GameColor.controlSurface
                .opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: DSSpacing.md) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(GameColor.controlSurface)
                    .frame(width: 58, height: 58)
                    .background(
                        Circle()
                            .fill(GameColor.successAccent)
                            .shadow(color: GameColor.successAccent.opacity(0.32), radius: 16, x: 0, y: 8)
                    )

                VStack(spacing: DSSpacing.xs) {
                    Text("+\(herbsAmount) herbs")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("Use herbs to reveal a hint.")
                        .font(DSTypography.body)
                        .foregroundStyle(GameColor.glassStroke.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(DSTypography.headline)
                        .foregroundStyle(GameColor.controlSurface)
                        .frame(width: 148, height: 46)
                        .background(
                            Capsule()
                                .fill(GameColor.controlAccent)
                                .shadow(color: GameColor.controlAccent.opacity(0.24), radius: 12, x: 0, y: 8)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.lg)
            .frame(width: 304)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(GameColor.controlSurface.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                            .stroke(GameColor.successAccent.opacity(0.42), lineWidth: 2)
                    )
            )
            .shadow(color: .black.opacity(0.34), radius: 24, x: 0, y: 16)
            .scaleEffect(reduceMotion ? 1 : 1.02)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Received \(herbsAmount) herbs. Use herbs to reveal a hint.")
    }
}

private struct HintPurchaseOverlay: View {
    let herbsBalance: Int
    let herbsCost: Int
    let canUseHerbs: Bool
    let canWatchAd: Bool
    let reduceMotion: Bool
    let onUseHerbs: () -> Void
    let onWatchAd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            GameColor.controlSurface
                .opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(spacing: DSSpacing.md) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(GameColor.controlSurface)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(GameColor.controlAccent)
                            .shadow(color: GameColor.controlAccent.opacity(0.3), radius: 16, x: 0, y: 8)
                    )

                VStack(spacing: DSSpacing.xs) {
                    Text("Get another hint?")
                        .font(DSTypography.title)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Label("\(herbsBalance) herbs available", systemImage: "leaf.fill")
                        .font(DSTypography.caption)
                        .foregroundStyle(GameColor.glassStroke.opacity(0.78))
                }

                VStack(spacing: DSSpacing.sm) {
                    hintAction(
                        title: "Use \(herbsCost) herbs",
                        systemName: "leaf.fill",
                        isEnabled: canUseHerbs,
                        action: onUseHerbs
                    )

                    if canWatchAd {
                        hintAction(
                            title: "Watch ad",
                            systemName: "play.rectangle.fill",
                            isEnabled: true,
                            action: onWatchAd
                        )
                    }
                }

                Button("Not now", action: onCancel)
                    .font(DSTypography.caption)
                    .foregroundStyle(GameColor.glassStroke.opacity(0.7))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.lg)
            .frame(width: 304)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                    .fill(GameColor.controlSurface.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                            .stroke(GameColor.controlAccent.opacity(0.42), lineWidth: 2)
                    )
            )
            .shadow(color: .black.opacity(0.36), radius: 24, x: 0, y: 16)
            .scaleEffect(reduceMotion ? 1 : 1.02)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Get another hint")
    }

    private func hintAction(
        title: String,
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(DSTypography.headline)
                .foregroundStyle(isEnabled ? GameColor.controlSurface : GameColor.glassStroke.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    Capsule()
                        .fill(isEnabled ? GameColor.controlAccent : GameColor.controlMuted.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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
    let isUnlockingPermanently: Bool
    let isRewardedUnlockAvailable: Bool
    let isPermanentUnlockAvailable: Bool
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
        if isRewardedUnlockAvailable {
            unlockAction(
                systemName: "play.circle.fill",
                title: isUnlockingForRound ? "Opening..." : "This order",
                subtitle: "Watch ad",
                footnote: "Temporary help",
                isEnabled: !isUnlockingForRound && !isUnlockingPermanently,
                action: onUnlockForRound
            )
        }

        if isPermanentUnlockAvailable {
            unlockAction(
                systemName: "sparkles",
                title: isUnlockingPermanently ? "Purchasing..." : "Always available",
                subtitle: "Purchase",
                footnote: "Permanent unlock",
                isEnabled: !isUnlockingForRound && !isUnlockingPermanently,
                action: onUnlockForever
            )
        }

        if !isRewardedUnlockAvailable && !isPermanentUnlockAvailable {
            Text("Extra flask unlock is disabled in this build.")
                .font(DSTypography.caption)
                .foregroundStyle(GameColor.glassStroke.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.lg)
        }
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
    let isHintAttentionActive: Bool
    let onHint: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            resetButton
                .frame(width: GameMetric.resetButtonWidth, height: GameMetric.resetButtonHeight)

            Spacer(minLength: DSSpacing.md)

            GameIconButton(
                systemName: "lightbulb.fill",
                title: "Hint",
                style: .hint,
                isEnabled: isHintEnabled,
                attractsAttention: isHintAttentionActive,
                action: onHint
            )
            .frame(width: GameMetric.iconButtonSize, height: GameMetric.iconButtonSize)
            .overlay(alignment: .topTrailing) {
                if !hintBadgeText.isEmpty {
                    HintCostBadge(text: hintBadgeText, isEnabled: isHintEnabled)
                        .offset(x: 6, y: -2)
                }
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
        case "Ad", "Ready":
            return "play.rectangle.fill"
        default:
            return "leaf.fill"
        }
    }
}

private struct GameIconButton: View {
    enum Style {
        case accent
        case hint
        case muted
    }

    let systemName: String
    let title: String
    let style: Style
    var isEnabled = true
    var attractsAttention = false
    let action: () -> Void

    @State private var attentionPulse = false

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
                        .stroke(borderColor, lineWidth: attractsAttention && attentionPulse ? 3 : 2)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.52)
        .shadow(color: attentionShadowColor, radius: attentionShadowRadius, x: 0, y: 0)
        .onAppear {
            updateAttentionPulse(isActive: attractsAttention)
        }
        .onChange(of: attractsAttention) { _, isActive in
            updateAttentionPulse(isActive: isActive)
        }
        .accessibilityLabel(title)
    }

    private var surfaceColor: Color {
        switch style {
        case .accent:
            return GameColor.controlAccent
        case .hint:
            return GameColor.controlSurface.opacity(0.94)
        case .muted:
            return GameColor.controlSurface.opacity(0.88)
        }
    }

    private var iconColor: Color {
        switch style {
        case .accent:
            return GameColor.controlSurface
        case .hint:
            return GameColor.hintAccent
        case .muted:
            return GameColor.glassStroke
        }
    }

    private var borderColor: Color {
        switch style {
        case .accent:
            return attractsAttention && attentionPulse ? Color.white.opacity(0.78) : Color.white.opacity(0.38)
        case .hint:
            if attractsAttention && attentionPulse {
                return GameColor.controlAccent.opacity(0.78)
            }
            return GameColor.hintAccent.opacity(0.38)
        case .muted:
            return Color.white.opacity(0.18)
        }
    }

    private var attentionShadowColor: Color {
        guard attractsAttention, isEnabled else { return .clear }
        return GameColor.hintAccent.opacity(attentionPulse ? 0.46 : 0.12)
    }

    private var attentionShadowRadius: CGFloat {
        guard attractsAttention, isEnabled else { return 0 }
        return attentionPulse ? 18 : 6
    }

    private func updateAttentionPulse(isActive: Bool) {
        guard isActive else {
            withAnimation(.easeOut(duration: 0.18)) {
                attentionPulse = false
            }
            return
        }

        attentionPulse = false
        withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
            attentionPulse = true
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
