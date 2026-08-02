import SwiftUI

struct AppRootView: View {
    @StateObject private var feedbackProvider: SystemGameFeedbackProvider
    @StateObject private var viewModel: HomeViewModel
    @State private var flow: AppFlow
    @State private var activeOrderLevelIndex: Int?
    @State private var hasTrackedAppLaunch = false
    private let analyticsProvider: any GameAnalyticsProviding
    private let crashReporter: any GameCrashReportingProviding
    private let playerActionLogger: any PlayerActionLoggingProviding

    @MainActor
    init() {
        self.init(
            analyticsProvider: NoOpGameAnalyticsProvider(),
            crashReporter: NoOpGameCrashReporter(),
            playerActionLogger: ConsolePlayerActionLogger()
        )
    }

    @MainActor
    init(
        analyticsProvider: any GameAnalyticsProviding,
        crashReporter: any GameCrashReportingProviding,
        playerActionLogger: any PlayerActionLoggingProviding,
        progressStore: (any ProgressStore)? = nil,
        featureFlags: GameFeatureFlags = .appDefault
    ) {
        let resolvedProgressStore = progressStore ?? UserDefaultsProgressStore()
        let feedbackProvider = SystemGameFeedbackProvider(progressStore: resolvedProgressStore)
        crashReporter.configure()
        let homeViewModel = HomeViewModel(
            progressStore: resolvedProgressStore,
            gameFeedbackProvider: feedbackProvider,
            gameAnalyticsProvider: analyticsProvider,
            playerActionLogger: playerActionLogger,
            featureFlags: featureFlags
        )
        self.analyticsProvider = analyticsProvider
        self.crashReporter = crashReporter
        self.playerActionLogger = playerActionLogger
        _feedbackProvider = StateObject(wrappedValue: feedbackProvider)
        _viewModel = StateObject(wrappedValue: homeViewModel)
        _activeOrderLevelIndex = State(
            initialValue: homeViewModel.hasActiveRoundInProgress ? homeViewModel.currentLevelIndex : nil
        )
        _flow = State(initialValue: AppFlow.initial(hasSeenIntro: homeViewModel.hasSeenIntro))
    }

    var body: some View {
        ZStack {
            switch flow {
            case .intro:
                IntroView {
                    viewModel.markIntroSeen()
                    withAnimation(.easeOut(duration: 0.28)) {
                        flow = .mainMenu
                    }
                }
                .transition(.opacity)
            case .mainMenu:
                MainMenuView(
                    herbsBalance: viewModel.herbsBalance,
                    levelNumber: viewModel.currentLevelNumber,
                    orderTitle: viewModel.orderTitle,
                    orderSubtitle: viewModel.orderSubtitle,
                    objectiveSummary: viewModel.orderObjectiveSummary,
                    completedOrders: viewModel.currentLevelIndex,
                    rewardText: viewModel.menuRewardText,
                    isCurrentOrderInProgress: activeOrderLevelIndex == viewModel.currentLevelIndex,
                    isSoundEnabled: feedbackProvider.isSoundEnabled,
                    isHapticsEnabled: feedbackProvider.isHapticsEnabled,
                    isDebugLevelJumpEnabled: viewModel.featureFlags.debugLevelJumpEnabled,
                    isDebugResetProgressEnabled: viewModel.featureFlags.debugResetProgressEnabled,
                    selectedThemeID: viewModel.selectedThemeID,
                    ownedThemeIDs: viewModel.ownedThemeIDs,
                    themePurchasePrompt: viewModel.themePurchasePrompt,
                    isThemeUnlockingWithAd: viewModel.isRewardedThemeUnlockInProgress,
                    onStartOrder: {
                        feedbackProvider.play(.uiTap)
                        playerActionLogger.log(
                            activeOrderLevelIndex == viewModel.currentLevelIndex
                                ? "level \(viewModel.currentLevelNumber) continued"
                                : "level \(viewModel.currentLevelNumber) started"
                        )
                        activeOrderLevelIndex = viewModel.currentLevelIndex
                        withAnimation(.easeOut(duration: 0.22)) {
                            flow = .game
                        }
                        Task { @MainActor in
                            await Task.yield()
                            viewModel.beginCurrentOrder()
                        }
                    },
                    onResetProgress: {
                        feedbackProvider.play(.reset)
                        playerActionLogger.log("reset progress menu opened")
                        activeOrderLevelIndex = nil
                        viewModel.resetProgress()
                    },
                    onJumpToLevel: { levelNumber in
                        feedbackProvider.play(.uiTap)
                        playerActionLogger.log("test level jump requested level \(levelNumber)")
                        activeOrderLevelIndex = nil
                        viewModel.jumpToLevelForTesting(levelNumber)
                    },
                    onToggleSound: {
                        playerActionLogger.log("sound toggled")
                        feedbackProvider.toggleSound()
                    },
                    onToggleHaptics: {
                        playerActionLogger.log("haptics toggled")
                        feedbackProvider.toggleHaptics()
                    },
                    onThemeTap: viewModel.handleThemeTap,
                    onDismissThemePurchase: viewModel.dismissThemePurchasePrompt,
                    onPurchaseThemeWithHerbs: viewModel.purchaseThemeWithHerbs,
                    onUnlockThemeWithAd: viewModel.unlockThemeWithRewardedAd
                )
                .transition(.opacity)
            case .game:
                NavigationStack {
                    HomeView(viewModel: viewModel) {
                        playerActionLogger.log("main menu opened from level \(viewModel.currentLevelNumber)")
                        withAnimation(.easeOut(duration: 0.22)) {
                            flow = .mainMenu
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .tint(selectedTheme.tokens.primaryAccent)
        .environment(\.gameTheme, selectedTheme.tokens)
        .onChange(of: viewModel.currentLevelIndex) { _, _ in
            guard flow == .game else { return }
            activeOrderLevelIndex = nil
            withAnimation(.easeOut(duration: 0.28)) {
                flow = .mainMenu
            }
        }
        .onAppear {
            updateCrashContext()
            trackAppLaunchIfNeeded()
            playerActionLogger.log(
                "app opened level \(viewModel.currentLevelNumber) herbs \(viewModel.herbsBalance)"
            )
        }
        .onChange(of: flow) { oldFlow, newFlow in
            updateCrashContext()
            playerActionLogger.log("\(newFlow.analyticsName) opened from \(oldFlow.analyticsName)")
            analyticsProvider.track(.appFlowChanged(
                from: oldFlow.analyticsName,
                to: newFlow.analyticsName,
                levelNumber: viewModel.currentLevelNumber
            ))
        }
        .onChange(of: viewModel.currentLevelNumber) { _, _ in
            updateCrashContext()
        }
        .onChange(of: viewModel.herbsBalance) { _, _ in
            updateCrashContext()
        }
    }

    private var selectedTheme: GameTheme {
        GameThemeCatalog.theme(id: viewModel.selectedThemeID) ?? GameThemeCatalog.base
    }

    private func updateCrashContext() {
        crashReporter.setContextValue(flow.analyticsName, for: .currentFlow)
        crashReporter.setContextValue("\(viewModel.currentLevelNumber)", for: .currentLevel)
        crashReporter.setContextValue("\(viewModel.herbsBalance)", for: .herbsBalance)
    }

    private func trackAppLaunchIfNeeded() {
        guard !hasTrackedAppLaunch else { return }

        hasTrackedAppLaunch = true
        analyticsProvider.track(.appLaunched(
            initialLevelNumber: viewModel.currentLevelNumber,
            herbsBalance: viewModel.herbsBalance
        ))
    }
}

enum AppFlow: Equatable {
    case intro
    case mainMenu
    case game

    static func initial(hasSeenIntro: Bool) -> AppFlow {
        hasSeenIntro ? .mainMenu : .intro
    }

    var analyticsName: String {
        switch self {
        case .intro:
            return "intro"
        case .mainMenu:
            return "main_menu"
        case .game:
            return "game"
        }
    }
}

private struct IntroView: View {
    @Environment(\.gameTheme) private var theme
    let onFinish: () -> Void
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            MenuBackgroundView()

            VStack(spacing: DSSpacing.lg) {
                Spacer()

                Image(systemName: "flask.fill")
                    .font(.system(size: 78, weight: .black, design: .rounded))
                    .foregroundStyle(theme.primaryAccent)
                    .shadow(color: theme.primaryAccent.opacity(0.28), radius: 14, x: 0, y: 8)
                    .accessibilityHidden(true)

                VStack(spacing: DSSpacing.xs) {
                    Text("Color Flask")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("Brew cozy potions. Sort the magic.")
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Spacer()

                Spacer()
            }
            .padding(.horizontal, DSSpacing.xl)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finish()
        }
        .task {
            guard !hasFinished else { return }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            finish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Color Flask. Brew cozy potions. Sort the magic.")
        .accessibilityHint("Tap anywhere to continue.")
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}

private struct MainMenuView: View {
    @Environment(\.gameTheme) private var theme
    let herbsBalance: Int
    let levelNumber: Int
    let orderTitle: String
    let orderSubtitle: String
    let objectiveSummary: OrderObjectiveSummary?
    let completedOrders: Int
    let rewardText: String
    let isCurrentOrderInProgress: Bool
    let isSoundEnabled: Bool
    let isHapticsEnabled: Bool
    let isDebugLevelJumpEnabled: Bool
    let isDebugResetProgressEnabled: Bool
    let selectedThemeID: String
    let ownedThemeIDs: Set<String>
    let themePurchasePrompt: ThemePurchasePrompt?
    let isThemeUnlockingWithAd: Bool
    let onStartOrder: () -> Void
    let onResetProgress: () -> Void
    let onJumpToLevel: (Int) -> Void
    let onToggleSound: () -> Void
    let onToggleHaptics: () -> Void
    let onThemeTap: (String) -> Void
    let onDismissThemePurchase: () -> Void
    let onPurchaseThemeWithHerbs: (String) -> Void
    let onUnlockThemeWithAd: (String) -> Void

    @State private var isResetConfirmationPresented = false
    @State private var isThemeShopPresented = false
    @State private var testLevelNumber = 1

    private var startOrderTitle: String {
        isCurrentOrderInProgress ? "Continue Order" : "Start Order"
    }

    private var startOrderIconName: String {
        isCurrentOrderInProgress ? "arrow.right.circle.fill" : "play.fill"
    }

    private var selectedThemeName: String {
        GameThemeCatalog.theme(id: selectedThemeID)?.name ?? GameThemeCatalog.base.name
    }

    var body: some View {
        ZStack {
            MenuBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    header

                    nextOrderPanel

                    Button(action: onStartOrder) {
                        Label(startOrderTitle, systemImage: startOrderIconName)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(theme.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                Capsule()
                                    .fill(theme.primaryAccent)
                                    .shadow(color: theme.primaryAccent.opacity(0.24), radius: 16, x: 0, y: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the current potion order.")

                    statsPanel

                    themeShopButton

                    if isDebugLevelJumpEnabled {
                        testLevelPanel
                    }

                    if isDebugResetProgressEnabled {
                        resetProgressButton
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.top, DSSpacing.xxl)
                .padding(.bottom, DSSpacing.xxl)
            }
        }
        .alert("Reset progress?", isPresented: $isResetConfirmationPresented) {
            Button("Cancel", role: .cancel) {}

            Button("Reset", role: .destructive) {
                onResetProgress()
            }
        } message: {
            Text("This will clear levels, herbs, and completed orders.")
        }
        .fullScreenCover(isPresented: $isThemeShopPresented) {
            ThemeShopView(
                herbsBalance: herbsBalance,
                selectedThemeID: selectedThemeID,
                ownedThemeIDs: ownedThemeIDs,
                themePurchasePrompt: themePurchasePrompt,
                isUnlockingWithAd: isThemeUnlockingWithAd,
                onThemeTap: onThemeTap,
                onDismissPurchase: onDismissThemePurchase,
                onPurchaseWithHerbs: onPurchaseThemeWithHerbs,
                onUnlockWithAd: onUnlockThemeWithAd
            ) {
                isThemeShopPresented = false
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Potion Shop")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Potion orders await")
                    .font(DSTypography.headline)
                    .foregroundStyle(theme.textPrimary.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: DSSpacing.sm)

            VStack(alignment: .trailing, spacing: DSSpacing.sm) {
                Label("\(herbsBalance)", systemImage: "leaf.fill")
                    .font(DSTypography.headline)
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, DSSpacing.md)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .fill(theme.success)
                    )
                    .accessibilityLabel("\(herbsBalance) herbs")

                HStack(spacing: DSSpacing.xs) {
                    MenuToggleButton(
                        systemImage: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        isEnabled: isSoundEnabled,
                        accessibilityLabel: isSoundEnabled ? "Sound on" : "Sound off",
                        action: onToggleSound
                    )

                    MenuToggleButton(
                        systemImage: isHapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                        isEnabled: isHapticsEnabled,
                        accessibilityLabel: isHapticsEnabled ? "Vibration on" : "Vibration off",
                        action: onToggleHaptics
                    )
                }
            }
        }
    }

    private var nextOrderPanel: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.sm) {
                Text("Level \(levelNumber)")
                    .font(DSTypography.caption)
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, DSSpacing.sm)
                    .frame(height: 26)
                    .background(
                        Capsule()
                            .fill(theme.primaryAccent)
                    )

                Spacer()

                RewardValueView(value: rewardText, font: DSTypography.caption)
                    .foregroundStyle(theme.textPrimary.opacity(0.76))
            }

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(orderTitle)
                    .font(DSTypography.title)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(orderSubtitle)
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary.opacity(0.72))
                    .lineLimit(2)
            }

            if let objectiveSummary {
                HStack(spacing: DSSpacing.sm) {
                    Circle()
                        .fill(objectiveSummary.targetColor.swiftUIColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.58), lineWidth: 2)
                        )

                    Text(objectiveSummary.potionName)
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(objectiveSummary.progressText)
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, DSSpacing.sm)
                        .frame(height: 28)
                        .background(
                            Capsule()
                                .fill(theme.primaryAccent)
                        )
                }
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                .fill(theme.surface.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                        .stroke(theme.softAccent.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.24), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var statsPanel: some View {
        HStack(spacing: DSSpacing.md) {
            MenuStatView(title: "Completed", value: "\(completedOrders)")
            MenuStatView(title: "Reward", value: rewardText, systemImage: "leaf.fill")
        }
    }

    private var themeShopButton: some View {
        Button {
            isThemeShopPresented = true
        } label: {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.primaryAccent))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Theme Shop")
                        .font(DSTypography.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text("\(selectedThemeName) active")
                        .font(DSTypography.caption)
                        .foregroundStyle(theme.textPrimary.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: DSSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary.opacity(0.72))
                    .accessibilityHidden(true)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.md)
                    .fill(theme.surface.opacity(0.64))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSCornerRadius.md)
                            .stroke(theme.softAccent.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open theme shop")
    }

    private var testLevelPanel: some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                testLevelNumber = max(1, testLevelNumber - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.surface.opacity(0.68)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous test level")

            Text("Level \(testLevelNumber)")
                .font(DSTypography.headline)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(theme.surface.opacity(0.68))
                        .overlay(
                            Capsule()
                                .stroke(theme.softAccent.opacity(0.16), lineWidth: 1)
                        )
                )

            Button {
                testLevelNumber = min(999, testLevelNumber + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.surface.opacity(0.68)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next test level")

            Button {
                onJumpToLevel(testLevelNumber)
            } label: {
                Label("Go", systemImage: "arrow.turn.down.right")
                    .font(DSTypography.headline)
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, DSSpacing.md)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(theme.success)
                    )
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .contain)
    }

    private var resetProgressButton: some View {
        Button("Reset Progress") {
            isResetConfirmationPresented = true
        }
        .font(DSTypography.headline)
        .foregroundStyle(theme.textPrimary.opacity(0.78))
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            Capsule()
                .fill(theme.surface.opacity(0.64))
                .overlay(
                    Capsule()
                        .stroke(theme.softAccent.opacity(0.14), lineWidth: 1)
                )
        )
        .buttonStyle(.plain)
    }
}

private struct MenuStatView: View {
    @Environment(\.gameTheme) private var theme
    let title: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(theme.success)
                        .accessibilityHidden(true)
                }

                if !value.isEmpty {
                    Text(value)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }
            }

            Text(title)
                .font(DSTypography.caption)
                .foregroundStyle(theme.textPrimary.opacity(0.66))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.md)
                .fill(theme.surface.opacity(0.64))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.md)
                        .stroke(theme.softAccent.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct RewardValueView: View {
    let value: String
    let font: Font

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "leaf.fill")

            if !value.isEmpty {
                Text(value)
            }
        }
        .font(font)
        .lineLimit(1)
        .accessibilityLabel(value.isEmpty ? "Herbs reward" : "\(value) herbs reward")
    }
}

private struct MenuToggleButton: View {
    @Environment(\.gameTheme) private var theme
    let systemImage: String
    let isEnabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(isEnabled ? theme.textOnAccent : theme.textPrimary.opacity(0.62))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEnabled ? theme.primaryAccent : theme.surface.opacity(0.58))
                        .overlay(
                            Circle()
                                .stroke(theme.softAccent.opacity(isEnabled ? 0.18 : 0.1), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ThemeShopView: View {
    @Environment(\.gameTheme) private var theme
    let herbsBalance: Int
    let selectedThemeID: String
    let ownedThemeIDs: Set<String>
    let themePurchasePrompt: ThemePurchasePrompt?
    let isUnlockingWithAd: Bool
    let onThemeTap: (String) -> Void
    let onDismissPurchase: () -> Void
    let onPurchaseWithHerbs: (String) -> Void
    let onUnlockWithAd: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            MenuBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    header

                    themeButton(for: GameThemeCatalog.base)

                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        Text("New Looks")
                            .font(DSTypography.headline)
                            .foregroundStyle(theme.textPrimary)

                        ForEach(GameThemeCatalog.shopThemes) { theme in
                            themeButton(for: theme)
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.top, DSSpacing.xxl)
                .padding(.bottom, DSSpacing.xxl)
            }
        }
        .sheet(item: themePurchaseBinding) { prompt in
            if let theme = GameThemeCatalog.theme(id: prompt.themeID) {
                ThemePurchaseSheet(
                    theme: theme,
                    herbsBalance: herbsBalance,
                    isUnlockingWithAd: isUnlockingWithAd,
                    onPurchaseWithHerbs: {
                        onPurchaseWithHerbs(theme.id)
                    },
                    onUnlockWithAd: {
                        onUnlockWithAd(theme.id)
                    }
                )
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var themePurchaseBinding: Binding<ThemePurchasePrompt?> {
        Binding(
            get: {
                themePurchasePrompt
            },
            set: { newValue in
                if newValue == nil {
                    onDismissPurchase()
                }
            }
        )
    }

    private func themeButton(for theme: GameTheme) -> some View {
        Button {
            onThemeTap(theme.id)
        } label: {
            ThemeShopCard(
                theme: theme,
                isOwned: ownedThemeIDs.contains(theme.id),
                isActive: selectedThemeID == theme.id
            )
        }
        .buttonStyle(.plain)
        .disabled(isUnlockingWithAd)
    }

    private var header: some View {
        HStack(spacing: DSSpacing.md) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(theme.surface.opacity(0.7)))
                    .overlay(
                        Circle()
                            .stroke(theme.softAccent.opacity(0.16), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close theme shop")

            VStack(alignment: .leading, spacing: 3) {
                Text("Theme Shop")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Potion room styles")
                    .font(DSTypography.body)
                    .foregroundStyle(theme.textPrimary.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: DSSpacing.sm)

            Label("\(herbsBalance)", systemImage: "leaf.fill")
                .font(DSTypography.headline)
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, DSSpacing.md)
                .frame(height: 38)
                .background(Capsule().fill(theme.success))
                .accessibilityLabel("\(herbsBalance) herbs")
        }
    }
}

private struct ThemePurchaseSheet: View {
    let theme: GameTheme
    let herbsBalance: Int
    let isUnlockingWithAd: Bool
    let onPurchaseWithHerbs: () -> Void
    let onUnlockWithAd: () -> Void

    private var herbsCost: Int {
        if case let .shop(herbsCost, _) = theme.commerceState {
            return herbsCost
        }

        return 0
    }

    private var canWatchAd: Bool {
        if case let .shop(_, adPreviewAvailable) = theme.commerceState {
            return adPreviewAvailable
        }

        return false
    }

    var body: some View {
        UnlockOfferSheet(
            title: "Unlock theme",
            subtitle: theme.name
        ) {
            ThemePreview(theme: theme)
        } actions: {
            UnlockOfferAction(
                systemName: "leaf.fill",
                title: "\(herbsCost) herbs",
                subtitle: herbsBalance >= herbsCost ? "Unlock now" : "Need \(herbsCost - herbsBalance)",
                footnote: "Permanent theme",
                isEnabled: herbsBalance >= herbsCost && !isUnlockingWithAd,
                action: onPurchaseWithHerbs
            )

            if canWatchAd {
                UnlockOfferAction(
                    systemName: "play.circle.fill",
                    title: isUnlockingWithAd ? "Opening..." : "Free",
                    subtitle: "Watch ad",
                    footnote: "Permanent theme",
                    isEnabled: !isUnlockingWithAd,
                    action: onUnlockWithAd
                )
            }
        }
    }
}

private struct ThemePreview: View {
    let theme: GameTheme

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.xs) {
                ForEach(Array(theme.paletteColors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .frame(width: 38, height: 54)
                }
            }

            Text(theme.subtitle)
                .font(DSTypography.caption)
                .foregroundStyle(theme.tokens.textPrimary.opacity(0.74))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                .fill(theme.tokens.surface.opacity(0.56))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.lg)
                        .stroke(theme.tokens.primaryAccent.opacity(0.68), lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.name) theme preview")
    }
}

private struct ThemeShopCard: View {
    let theme: GameTheme
    let isOwned: Bool
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(Array(theme.paletteColors.enumerated()), id: \.offset) { _, color in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color)
                            .frame(width: 28, height: 34)
                    }
                }
                .accessibilityHidden(true)

                Text(theme.name)
                    .font(DSTypography.headline)
                    .foregroundStyle(theme.tokens.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(theme.subtitle)
                    .font(DSTypography.caption)
                    .foregroundStyle(theme.tokens.textPrimary.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: DSSpacing.sm)

            VStack(alignment: .trailing, spacing: DSSpacing.sm) {
                commerceBadge

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(theme.tokens.success)
                        .accessibilityLabel("Active")
                }
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSCornerRadius.md)
                .fill(theme.tokens.surface.opacity(isActive ? 0.82 : 0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.md)
                        .stroke(
                            isActive ? theme.tokens.primaryAccent : theme.tokens.softAccent.opacity(0.16),
                            lineWidth: isActive ? 2 : 1
                        )
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var commerceBadge: some View {
        HStack(spacing: 4) {
            if isActive {
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
                Text("Selected")
                    .lineLimit(1)
            } else if isOwned {
                Image(systemName: "checkmark")
                    .accessibilityHidden(true)
                Text("Owned")
                    .lineLimit(1)
            } else if case let .shop(_, adPreviewAvailable) = theme.commerceState {
                Image(systemName: "leaf.fill")
                    .accessibilityHidden(true)

                if adPreviewAvailable {
                    Image(systemName: "play.rectangle.fill")
                        .accessibilityHidden(true)
                }

                Text(theme.commerceState.title)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(theme.tokens.textOnAccent)
        .padding(.horizontal, DSSpacing.xs)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(theme.tokens.primaryAccent)
        )
    }

    private var accessibilityLabel: String {
        if isActive {
            return "\(theme.name), selected theme"
        }

        if isOwned {
            return "\(theme.name), owned theme"
        }

        if case let .shop(herbsCost, adPreviewAvailable) = theme.commerceState {
            return "\(theme.name), shop theme, costs \(herbsCost) herbs"
                + (adPreviewAvailable ? ", ad preview available" : "")
        }

        return "\(theme.name), theme"
    }
}

private struct MenuBackgroundView: View {
    @Environment(\.gameTheme) private var theme

    var body: some View {
        ZStack {
            theme.backgroundPrimary
                .ignoresSafeArea()

            Image("GameBackground")
                .resizable()
                .scaledToFill()
                .saturation(0.74)
                .opacity(0.78)
                .ignoresSafeArea()

            theme.surface
                .opacity(0.3)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .clear,
                    theme.backgroundPrimary.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
