import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: HomeViewModel
    @State private var bonusSheetHeight: CGFloat = 260
    private let layout = HomeLayout()

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutScale = layout.scale(in: proxy.size)

            ZStack {
                gameBackground(in: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    .zIndex(GameLayer.background)

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
                onUnlockForRound: {
                    viewModel.unlockBonusFlaskForCurrentRound()
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
            LevelBadge(levelNumber: viewModel.currentLevelNumber)
                .scaleEffect(scale)
                .frame(width: 118 * scale, height: 36 * scale)
                .position(
                    x: size.width / 2,
                    y: controlCenterY
                )

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
        let topControlCenterY = safeAreaInsets.top + GameMetric.topControlInset * scale + scaledIconSize / 2
        return CGPoint(
            x: size.width / 2,
            y: topControlCenterY + 58 * scale
        )
    }

    private func bottomControls(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> some View {
        let scaledIconSize = GameMetric.iconButtonSize * scale
        let controlCenterY = layout.bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets, scale: scale)

        return ZStack {
            resetButton(scale: scale, isEnabled: viewModel.canInteractWithBoard)
                .position(
                    x: GameMetric.horizontalInset * scale + GameMetric.resetButtonWidth * scale / 2,
                    y: controlCenterY
                )

            GameIconButton(
                systemName: "lightbulb.fill",
                title: "Hint",
                style: .accent,
                isEnabled: viewModel.canShowHint
            ) {
                viewModel.showHint()
            }
                .scaleEffect(scale)
                .frame(width: scaledIconSize, height: scaledIconSize)
                .position(
                    x: size.width - GameMetric.horizontalInset * scale - scaledIconSize / 2,
                    y: controlCenterY
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

}

private struct LevelBadge: View {
    let levelNumber: Int

    var body: some View {
        Text("Level \(levelNumber)")
            .font(DSTypography.headline)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: 118, height: 36)
            .background {
                Capsule()
                    .fill(GameColor.controlSurface.opacity(0.84))
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 6)
            .accessibilityLabel("Level \(levelNumber)")
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
        .padding(.vertical, DSSpacing.xs)
        .frame(width: 220, alignment: .leading)
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
        .frame(width: 220 * scale, height: 52 * scale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
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

                if let herbsReward {
                    Label("+\(herbsReward) herbs", systemImage: "leaf.fill")
                        .font(DSTypography.headline)
                        .foregroundStyle(GameColor.controlSurface)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.xs)
                        .background(
                            Capsule()
                                .fill(GameColor.successAccent)
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.42), lineWidth: 1)
                                )
                        )
                        .shadow(color: GameColor.successAccent.opacity(0.24), radius: 12, x: 0, y: 8)
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
        if let herbsReward {
            return "\(message). Earned \(herbsReward) herbs. Next potion brewing."
        }

        return "\(message). Next potion brewing."
    }
}
