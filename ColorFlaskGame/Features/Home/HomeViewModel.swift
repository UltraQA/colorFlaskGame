import SwiftUI
import Combine

struct PourAnimation: Identifiable, Equatable {
    let id = UUID()
    let sourceIndex: Int
    let targetIndex: Int
    let color: LiquidColor
}

struct HintMove: Equatable {
    let sourceIndex: Int
    let targetIndex: Int
}

enum RewardedAdPlacement: Equatable {
    case extraHint
    case bonusFlask
}

enum PurchaseProduct: Equatable {
    case permanentBonusFlask
}

enum PurchaseResult: Equatable {
    case purchased
    case cancelled
    case failed
}

extension PurchaseResult {
    var logName: String {
        switch self {
        case .purchased:
            return "purchased"
        case .cancelled:
            return "cancelled"
        case .failed:
            return "failed"
        }
    }
}

protocol RewardedAdProviding {
    func showRewardedAd(for placement: RewardedAdPlacement) async -> Bool
}

protocol BonusFlaskPurchaseProviding {
    func purchase(_ product: PurchaseProduct) async -> PurchaseResult
}

struct StubRewardedAdProvider: RewardedAdProviding {
    func showRewardedAd(for placement: RewardedAdPlacement) async -> Bool {
        true
    }
}

struct StubBonusFlaskPurchaseProvider: BonusFlaskPurchaseProviding {
    let result: PurchaseResult

    init(result: PurchaseResult = .purchased) {
        self.result = result
    }

    func purchase(_ product: PurchaseProduct) async -> PurchaseResult {
        result
    }
}

struct GameFeatureFlags: Equatable {
    let rewardedAdsEnabled: Bool
    let permanentBonusFlaskPurchaseEnabled: Bool

    static let alpha = GameFeatureFlags(
        rewardedAdsEnabled: true,
        permanentBonusFlaskPurchaseEnabled: false
    )

    static let allEnabled = GameFeatureFlags(
        rewardedAdsEnabled: true,
        permanentBonusFlaskPurchaseEnabled: true
    )
}

struct BonusUnlockPrompt: Identifiable, Equatable {
    let flaskIndex: Int

    var id: Int {
        flaskIndex
    }
}

struct ResetConfirmationPrompt: Identifiable, Equatable {
    let id = UUID()
}

struct HerbsTutorialPrompt: Identifiable, Equatable {
    let id = UUID()
    let herbsAmount: Int
}

enum TutorialMarkerKind: Equatable {
    case correctTarget
    case blockedTarget
}

struct TutorialMarker: Equatable {
    let flaskIndex: Int
    let kind: TutorialMarkerKind
}

struct OrderObjectiveSummary: Equatable {
    let potionName: String
    let targetColor: LiquidColor
    let progress: Int
    let requiredSections: Int
    let shortCopy: String

    var progressText: String {
        "\(progress)/\(requiredSections)"
    }
}

private enum HintPaymentMode {
    case free
    case herbs
    case rewardedAd
    case unavailable
}

private extension HintPaymentMode {
    var analyticsPayment: HintAnalyticsPayment {
        switch self {
        case .free:
            return .free
        case .herbs:
            return .herbs
        case .rewardedAd:
            return .rewardedAd
        case .unavailable:
            assertionFailure("Unavailable hint payment should not be tracked as a used hint.")
            return .free
        }
    }

    var logName: String {
        switch self {
        case .free:
            return "free"
        case .herbs:
            return "herbs"
        case .rewardedAd:
            return "rewarded_ad"
        case .unavailable:
            return "unavailable"
        }
    }
}

enum LevelCompletionPhase: Equatable {
    case playing
    case resolvingWin
    case celebrating
    case transitioningToNextLevel

    var isPlaying: Bool {
        self == .playing
    }

    var showsSparkles: Bool {
        self != .playing
    }

    var showsMessageOverlay: Bool {
        self == .celebrating || self == .transitioningToNextLevel
    }
}

struct HomeViewModelTiming: Equatable {
    let pourAnimationDuration: TimeInterval
    let completionDuration: TimeInterval
    let invalidFeedbackDuration: TimeInterval

    static let live = HomeViewModelTiming(
        pourAnimationDuration: 0.55,
        completionDuration: 3.1,
        invalidFeedbackDuration: 0.32
    )

    static let immediate = HomeViewModelTiming(
        pourAnimationDuration: 0,
        completionDuration: 0,
        invalidFeedbackDuration: 0
    )
}

@MainActor
final class HomeViewModel: ObservableObject {
    nonisolated static let herbsRewardPerCompletedOrder = 8
    nonisolated static let extraHintHerbsCost = 2
    nonisolated static let victoryMessages = [
        "Potion Perfect!",
        "Order Brewed!",
        "Shelf Restocked!",
        "Well Bottled!",
        "Elixir Ready!",
        "Fresh Batch!"
    ]

    @Published private(set) var gameManager: GameManager
    @Published private(set) var selectedFlaskIndex: Int?
    @Published private(set) var pourAnimation: PourAnimation?
    @Published private(set) var hintMove: HintMove?
    @Published private(set) var invalidFlaskIndices: Set<Int> = []
    @Published private(set) var invalidMoveCount = 0
    @Published var bonusUnlockPrompt: BonusUnlockPrompt?
    @Published private(set) var completionPhase: LevelCompletionPhase = .playing
    @Published private(set) var moves = 0
    @Published private(set) var isBonusFlaskPermanentlyUnlocked: Bool
    @Published private(set) var currentLevelIndex: Int
    @Published private(set) var victoryMessage: String?
    @Published private(set) var herbsBalance: Int
    @Published private(set) var lastHerbsReward: Int?
    @Published private(set) var lastCompletedMoveCount: Int?
    @Published private(set) var hintsUsedThisLevel = 0
    @Published private(set) var isRewardedHintInProgress = false
    @Published private(set) var isRewardedBonusUnlockInProgress = false
    @Published private(set) var isPermanentBonusUnlockInProgress = false
    @Published private(set) var isOrderBannerVisible = true
    @Published private(set) var isTutorialPromptVisible: Bool
    @Published var resetConfirmationPrompt: ResetConfirmationPrompt?
    @Published var herbsTutorialPrompt: HerbsTutorialPrompt?

    private var cancellables: Set<AnyCancellable> = []
    private var history: [[Flask]] = []
    private let levelRepository: any LevelRepository
    private var progressStore: any ProgressStore
    private let rewardedAdProvider: any RewardedAdProviding
    private let bonusFlaskPurchaseProvider: any BonusFlaskPurchaseProviding
    private let gameFeedbackProvider: any GameFeedbackProviding
    private let gameAnalyticsProvider: any GameAnalyticsProviding
    private let playerActionLogger: any PlayerActionLoggingProviding
    let featureFlags: GameFeatureFlags
    private let timing: HomeViewModelTiming
    private let victoryMessageProvider: () -> String
    private var completionSequenceID = 0
    private var pourAnimationTask: Task<Void, Never>?
    private var invalidFeedbackTask: Task<Void, Never>?
    private var rewardedHintTask: Task<Void, Never>?
    private var rewardedBonusUnlockTask: Task<Void, Never>?
    private var permanentBonusUnlockTask: Task<Void, Never>?
    private var completionTasks: [Task<Void, Never>] = []

    init(
        gameManager: GameManager? = nil,
        levelRepository: any LevelRepository = HandcraftedLevelRepository(),
        progressStore: (any ProgressStore)? = nil,
        userDefaults: UserDefaults = .standard,
        currentLevelIndex: Int? = nil,
        isBonusFlaskPermanentlyUnlocked: Bool? = nil,
        rewardedAdProvider: any RewardedAdProviding = StubRewardedAdProvider(),
        bonusFlaskPurchaseProvider: any BonusFlaskPurchaseProviding = StubBonusFlaskPurchaseProvider(),
        gameFeedbackProvider: (any GameFeedbackProviding)? = nil,
        gameAnalyticsProvider: (any GameAnalyticsProviding)? = nil,
        playerActionLogger: (any PlayerActionLoggingProviding)? = nil,
        featureFlags: GameFeatureFlags = .alpha,
        timing: HomeViewModelTiming = .live,
        victoryMessageProvider: @escaping () -> String = {
            HomeViewModel.victoryMessages.randomElement() ?? "Fantastic!"
        }
    ) {
        self.levelRepository = levelRepository
        let resolvedProgressStore = progressStore ?? UserDefaultsProgressStore(userDefaults: userDefaults)
        self.progressStore = resolvedProgressStore
        self.rewardedAdProvider = rewardedAdProvider
        self.bonusFlaskPurchaseProvider = bonusFlaskPurchaseProvider
        self.gameFeedbackProvider = gameFeedbackProvider ?? NoOpGameFeedbackProvider()
        self.gameAnalyticsProvider = gameAnalyticsProvider ?? NoOpGameAnalyticsProvider()
        self.playerActionLogger = playerActionLogger ?? NoOpPlayerActionLogger()
        self.featureFlags = featureFlags
        self.timing = timing
        self.victoryMessageProvider = victoryMessageProvider
        let resolvedLevelIndex = currentLevelIndex ?? resolvedProgressStore.currentLevelIndex
        let resolvedBonusUnlock = isBonusFlaskPermanentlyUnlocked ?? resolvedProgressStore.isBonusFlaskPermanentlyUnlocked
        self.currentLevelIndex = resolvedLevelIndex
        self.isBonusFlaskPermanentlyUnlocked = resolvedBonusUnlock
        self.herbsBalance = resolvedProgressStore.herbsBalance
        self.isTutorialPromptVisible = Self.shouldShowTutorial(
            levelNumber: resolvedLevelIndex + 1,
            hasCompletedOnboarding: resolvedProgressStore.hasCompletedOnboarding
        )
        self.gameManager = gameManager ?? .makeInitialLevel(
            levelIndex: resolvedLevelIndex,
            levelRepository: levelRepository,
            isBonusFlaskUnlocked: resolvedBonusUnlock
        )
        self.selectedFlaskIndex = self.gameManager.level?.initialSelectedFlaskIndex
        bindGameManager()
    }

    var progress: Double {
        let playableFlasks = gameManager.playableFlasks
        guard !playableFlasks.isEmpty else { return 0 }
        let solvedCount = playableFlasks.filter(\.isSolved).count
        return Double(solvedCount) / Double(playableFlasks.count)
    }

    var completedFlasks: Int {
        gameManager.playableFlasks.filter(\.isSolved).count
    }

    var totalFlasks: Int {
        gameManager.playableFlasks.count
    }

    var currentLevelNumber: Int {
        (gameManager.level?.id ?? currentLevelIndex + 1)
    }

    var orderTitle: String {
        "Order \(currentLevelNumber)"
    }

    var orderSubtitle: String {
        if let objectiveSummary = orderObjectiveSummary {
            return objectiveSummary.shortCopy
        }

        return currentLevelNumber == 1 ? "Brew your first potion" : "Sort today's potions"
    }

    var orderObjectiveSummary: OrderObjectiveSummary? {
        guard let level = gameManager.level,
              case let .completeColor(targetColor) = level.objective else {
            return nil
        }

        let order = level.customerOrder
        return OrderObjectiveSummary(
            potionName: order?.potionName ?? "\(targetColor.accessibilityName.capitalized) Potion",
            targetColor: targetColor,
            progress: targetColorProgress(for: targetColor),
            requiredSections: gameManager.level?.flaskCapacity ?? Flask.maxCapacity,
            shortCopy: order?.shortCopy ?? "Complete one \(targetColor.accessibilityName) flask"
        )
    }

    var tutorialTitle: String {
        switch currentLevelNumber {
        case 1:
            return "Pour a potion"
        case 2:
            return "Match colors"
        case 3:
            return "Sort more colors"
        case 4:
            return "Brew the order"
        case 5:
            return "Use herbs"
        default:
            return "Sort the order"
        }
    }

    var tutorialSubtitle: String {
        switch currentLevelNumber {
        case 1:
            return "Tap one flask, then another."
        case 2:
            return "Only pour into the same color."
        case 3:
            return "Use empty flasks to move groups."
        case 4:
            return "Complete the requested potion color."
        case 5:
            return "Spend earned herbs on hints."
        default:
            return "Clear every potion to finish the order."
        }
    }

    var tutorialMove: HintMove? {
        guard currentLevelNumber < 5,
              isTutorialPromptVisible,
              let plan = gameManager.firstValidMove() else { return nil }
        return HintMove(sourceIndex: plan.sourceIndex, targetIndex: plan.targetIndex)
    }

    var canUndo: Bool {
        completionPhase.isPlaying
            && !history.isEmpty
            && pourAnimation == nil
            && !isRewardedAdInProgress
    }

    var canShowHint: Bool {
        completionPhase.isPlaying
            && pourAnimation == nil
            && !isRewardedAdInProgress
            && herbsTutorialPrompt == nil
            && !gameManager.isRoundCompleted
            && gameManager.hasAvailableMove()
            && nextHintPaymentMode != .unavailable
    }

    var shouldPromptHintUse: Bool {
        currentLevelNumber == 5
            && progressStore.hasSeenHerbsTutorial
            && herbsTutorialPrompt == nil
            && hintsUsedThisLevel == 0
            && hintMove == nil
            && completionPhase.isPlaying
            && !isRewardedAdInProgress
    }

    var canInteractWithBoard: Bool {
        completionPhase.isPlaying
            && pourAnimation == nil
            && !isRewardedAdInProgress
            && !requiresMandatoryHintBeforePlay
    }

    var hintBadgeText: String {
        switch nextHintPaymentMode {
        case .free:
            return "Free"
        case .herbs:
            return "\(Self.extraHintHerbsCost)"
        case .rewardedAd:
            return "Ad"
        case .unavailable:
            return ""
        }
    }

    var menuRewardText: String {
        currentLevelNumber <= 4 ? "" : "+\(Self.herbsRewardPerCompletedOrder)"
    }

    func handleFlaskTap(at index: Int) {
        guard gameManager.flasks.indices.contains(index), canInteractWithBoard else { return }

        dismissOrderBanner()
        dismissTutorialPromptIfNeeded()
        let flask = gameManager.flasks[index]

        guard flask.isPlayable else {
            if flask.isBonus {
                gameFeedbackProvider.play(.uiTap)
                gameAnalyticsProvider.track(.bonusFlaskPromptShown(levelNumber: currentLevelNumber))
                playerActionLogger.log("bonus flask menu opened on level \(currentLevelNumber)")
                bonusUnlockPrompt = BonusUnlockPrompt(flaskIndex: index)
            }
            return
        }

        hintMove = nil

        guard let sourceIndex = selectedFlaskIndex else {
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? nil : index
            gameFeedbackProvider.play(selectedFlaskIndex == nil ? .uiTap : .flaskSelect)
            if selectedFlaskIndex == nil {
                playerActionLogger.log("flask \(index + 1) tapped empty on level \(currentLevelNumber)")
            } else {
                playerActionLogger.log("flask \(index + 1) selected on level \(currentLevelNumber)")
            }
            return
        }

        guard sourceIndex != index else {
            selectedFlaskIndex = nil
            gameFeedbackProvider.play(.uiTap)
            playerActionLogger.log("flask \(index + 1) deselected on level \(currentLevelNumber)")
            return
        }

        switch gameManager.pourPlan(from: sourceIndex, to: index) {
        case let .success(plan):
            animatePour(plan)
        case let .failure(error):
            playerActionLogger.log(
                "invalid pour flask \(sourceIndex + 1) to flask \(index + 1) on level \(currentLevelNumber): \(error.localizedDescription)"
            )
            showInvalidMoveFeedback(sourceIndex: sourceIndex, targetIndex: index)
            selectedFlaskIndex = sourceIndex
        }
    }

    func undo() {
        guard canUndo, let previousFlasks = history.popLast() else { return }

        gameFeedbackProvider.play(.undo)
        gameAnalyticsProvider.track(.undoUsed(levelNumber: currentLevelNumber))
        playerActionLogger.log("undo used on level \(currentLevelNumber)")
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        gameManager.restore(flasks: previousFlasks)
        moves = max(0, moves - 1)
        objectWillChange.send()
    }

    func showHint() {
        guard pourAnimation == nil,
              !isRewardedAdInProgress,
              herbsTutorialPrompt == nil,
              let plan = gameManager.firstValidMove() else { return }
        guard currentLevelNumber != 5 || progressStore.hasSeenHerbsTutorial else { return }

        dismissOrderBanner()
        dismissTutorialPromptIfNeeded()
        let nextHint = HintMove(sourceIndex: plan.sourceIndex, targetIndex: plan.targetIndex)
        guard hintMove != nextHint else { return }

        let paymentMode = nextHintPaymentMode
        playerActionLogger.log("hint requested on level \(currentLevelNumber) payment \(paymentMode.logName)")
        switch paymentMode {
        case .rewardedAd:
            requestRewardedHint(nextHint)
        case .unavailable:
            return
        case .free, .herbs:
            applyHint(nextHint, paymentMode: paymentMode)
        }
    }

    func startNewGame() {
        loadLevel(at: currentLevelIndex)
    }

    func beginCurrentOrder() {
        gameAnalyticsProvider.track(.levelStarted(levelNumber: currentLevelNumber))
        playerActionLogger.log("level \(currentLevelNumber) order began")
        presentHerbsTutorialIfNeeded()
    }

    func requestReset() {
        guard canInteractWithBoard else { return }

        dismissOrderBanner()
        dismissTutorialPromptIfNeeded()
        gameAnalyticsProvider.track(.resetRequested(levelNumber: currentLevelNumber))
        playerActionLogger.log("reset requested on level \(currentLevelNumber)")
        guard moves > 0 || currentLevelNumber >= Level.lockedBonusIntroductionLevelID else {
            startNewGame()
            return
        }

        resetConfirmationPrompt = ResetConfirmationPrompt()
    }

    func confirmReset() {
        resetConfirmationPrompt = nil
        gameFeedbackProvider.play(.reset)
        gameAnalyticsProvider.track(.resetConfirmed(levelNumber: currentLevelNumber))
        playerActionLogger.log("reset confirmed on level \(currentLevelNumber)")
        startNewGame()
    }

    func cancelReset() {
        resetConfirmationPrompt = nil
    }

    func resetProgressForTesting() {
        resetProgress()
    }

    func resetProgress() {
        playerActionLogger.log("progress reset")
        progressStore.currentLevelIndex = 0
        progressStore.isBonusFlaskPermanentlyUnlocked = false
        progressStore.herbsBalance = 0
        progressStore.hasCompletedOnboarding = false
        progressStore.hasSeenHerbsTutorial = false
        isBonusFlaskPermanentlyUnlocked = false
        herbsBalance = 0
        resetConfirmationPrompt = nil
        herbsTutorialPrompt = nil
        loadLevel(at: 0)
    }

    func advanceToNextLevel() {
        loadLevel(at: currentLevelIndex + 1)
    }

    func jumpToLevelForTesting(_ levelNumber: Int) {
        playerActionLogger.log("debug jump to level \(max(1, levelNumber))")
        loadLevel(at: max(1, levelNumber) - 1)
    }

    private func loadLevel(at levelIndex: Int) {
        cancelScheduledWork()
        selectedFlaskIndex = nil
        pourAnimation = nil
        hintMove = nil
        bonusUnlockPrompt = nil
        resetConfirmationPrompt = nil
        herbsTutorialPrompt = nil
        invalidFlaskIndices.removeAll()
        completionPhase = .playing
        victoryMessage = nil
        lastHerbsReward = nil
        lastCompletedMoveCount = nil
        hintsUsedThisLevel = 0
        isOrderBannerVisible = true
        updateTutorialVisibility(for: levelIndex)
        completionSequenceID += 1
        history.removeAll()
        moves = 0
        currentLevelIndex = levelIndex
        progressStore.currentLevelIndex = levelIndex
        gameManager = .makeInitialLevel(
            levelIndex: levelIndex,
            levelRepository: levelRepository,
            isBonusFlaskUnlocked: isBonusFlaskPermanentlyUnlocked
        )
        selectedFlaskIndex = gameManager.level?.initialSelectedFlaskIndex
        bindGameManager()
        objectWillChange.send()
    }

    func unlockBonusFlaskForCurrentRound() {
        guard completionPhase.isPlaying else { return }
        gameFeedbackProvider.play(.uiTap)
        playerActionLogger.log("bonus flask opened for current round on level \(currentLevelNumber)")
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    func requestBonusFlaskUnlockForCurrentRound() {
        guard featureFlags.rewardedAdsEnabled,
              completionPhase.isPlaying,
              !isRewardedAdInProgress else { return }

        rewardedBonusUnlockTask?.cancel()
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        isRewardedBonusUnlockInProgress = true
        gameAnalyticsProvider.track(.bonusFlaskUnlockStarted(
            levelNumber: currentLevelNumber,
            method: .rewardedAd
        ))
        gameAnalyticsProvider.track(.rewardedAdStarted(
            levelNumber: currentLevelNumber,
            placement: .bonusFlask
        ))
        playerActionLogger.log("rewarded ad started for bonus flask on level \(currentLevelNumber)")

        rewardedBonusUnlockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let didEarnReward = await self.rewardedAdProvider.showRewardedAd(for: .bonusFlask)
            guard !Task.isCancelled else { return }

            self.rewardedBonusUnlockTask = nil
            self.isRewardedBonusUnlockInProgress = false
            self.gameAnalyticsProvider.track(.rewardedAdCompleted(
                levelNumber: self.currentLevelNumber,
                placement: .bonusFlask,
                success: didEarnReward
            ))
            self.gameAnalyticsProvider.track(.bonusFlaskUnlockCompleted(
                levelNumber: self.currentLevelNumber,
                method: .rewardedAd,
                success: didEarnReward
            ))
            self.playerActionLogger.log(
                "rewarded ad completed for bonus flask on level \(self.currentLevelNumber) success \(didEarnReward)"
            )
            guard didEarnReward else { return }

            self.unlockBonusFlaskForCurrentRound()
        }
    }

    func unlockBonusFlaskPermanently() {
        guard featureFlags.permanentBonusFlaskPurchaseEnabled,
              completionPhase.isPlaying,
              !isRewardedAdInProgress,
              !isPermanentBonusUnlockInProgress else { return }
        gameFeedbackProvider.play(.uiTap)
        permanentBonusUnlockTask?.cancel()
        gameAnalyticsProvider.track(.bonusFlaskUnlockStarted(
            levelNumber: currentLevelNumber,
            method: .permanentPurchase
        ))
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        isPermanentBonusUnlockInProgress = true
        gameAnalyticsProvider.track(.purchaseStarted(
            levelNumber: currentLevelNumber,
            product: .permanentBonusFlask
        ))
        playerActionLogger.log("purchase started permanent bonus flask on level \(currentLevelNumber)")

        permanentBonusUnlockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.bonusFlaskPurchaseProvider.purchase(.permanentBonusFlask)
            guard !Task.isCancelled else { return }

            self.permanentBonusUnlockTask = nil
            self.isPermanentBonusUnlockInProgress = false
            self.gameAnalyticsProvider.track(.purchaseCompleted(
                levelNumber: self.currentLevelNumber,
                product: .permanentBonusFlask,
                result: result
            ))
            self.gameAnalyticsProvider.track(.bonusFlaskUnlockCompleted(
                levelNumber: self.currentLevelNumber,
                method: .permanentPurchase,
                success: result == .purchased
            ))
            self.playerActionLogger.log(
                "purchase completed permanent bonus flask on level \(self.currentLevelNumber) result \(result.logName)"
            )
            guard result == .purchased else { return }

            self.bonusUnlockPrompt = nil
            self.isBonusFlaskPermanentlyUnlocked = true
            self.progressStore.isBonusFlaskPermanentlyUnlocked = true
            self.gameManager.unlockBonusFlaskForCurrentRound()
            self.objectWillChange.send()
        }
    }

    private func animatePour(_ plan: PourPlan) {
        pourAnimationTask?.cancel()
        gameFeedbackProvider.play(.validPour)
        playerActionLogger.log(
            "flask \(plan.sourceIndex + 1) to flask \(plan.targetIndex + 1) color \(plan.color.accessibilityName) amount \(plan.amount)"
        )
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        history.append(gameManager.flasks)
        pourAnimation = PourAnimation(
            sourceIndex: plan.sourceIndex,
            targetIndex: plan.targetIndex,
            color: plan.color
        )

        pourAnimationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.sleep(for: self.timing.pourAnimationDuration) else { return }

            withAnimation(.snappy(duration: 0.25)) {
                if case .success = self.gameManager.pour(from: plan.sourceIndex, to: plan.targetIndex) {
                    self.moves += 1
                    self.playerActionLogger.log(
                        "pour applied move \(self.moves) on level \(self.currentLevelNumber)"
                    )
                }
                self.pourAnimation = nil
            }

            self.completeRoundIfNeeded()
        }
    }

    private func showInvalidMoveFeedback(sourceIndex: Int, targetIndex: Int) {
        invalidFeedbackTask?.cancel()
        gameFeedbackProvider.play(.invalidMove)
        playerActionLogger.log(
            "invalid move feedback flask \(sourceIndex + 1) to flask \(targetIndex + 1) on level \(currentLevelNumber)"
        )
        invalidFlaskIndices = [sourceIndex, targetIndex]
        withAnimation(.linear(duration: timing.invalidFeedbackDuration)) {
            invalidMoveCount += 1
        }

        invalidFeedbackTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.sleep(for: self.timing.invalidFeedbackDuration) else { return }

            self.invalidFlaskIndices.removeAll()
        }
    }

    func skipCompletionInterlude() {
        guard completionPhase == .celebrating else { return }

        completionSequenceID += 1
        let sequenceID = completionSequenceID

        withAnimation(.easeOut(duration: 0.18)) {
            completionPhase = .transitioningToNextLevel
        }

        cancelCompletionTasks()
        let transitionTask = Task { @MainActor [weak self] in
            guard let self, self.completionSequenceID == sequenceID else { return }
            guard await self.sleep(for: self.nextLevelTransitionDuration),
                  self.completionSequenceID == sequenceID else { return }

            withAnimation(.easeOut(duration: 0.25)) {
                self.advanceToNextLevel()
            }
        }
        completionTasks = [transitionTask]
    }

    private func completeRoundIfNeeded() {
        guard gameManager.isRoundCompleted, completionPhase.isPlaying else { return }

        selectedFlaskIndex = nil
        hintMove = nil
        victoryMessage = completionMessage()
        lastCompletedMoveCount = moves
        gameFeedbackProvider.play(.levelComplete)
        awardHerbsForCompletedOrder()
        playerActionLogger.log(
            "level \(currentLevelNumber) completed moves \(moves) herbs reward \(lastHerbsReward ?? 0)"
        )
        gameAnalyticsProvider.track(.levelCompleted(
            levelNumber: currentLevelNumber,
            moves: moves,
            herbsReward: lastHerbsReward
        ))
        completionSequenceID += 1
        let sequenceID = completionSequenceID
        completionPhase = .resolvingWin

        cancelCompletionTasks()
        completionTasks = [
            Task { @MainActor [weak self] in
                guard let self, self.completionSequenceID == sequenceID else { return }
                guard await self.sleep(for: self.microCelebrationDuration),
                      self.completionSequenceID == sequenceID else { return }

                withAnimation(.easeOut(duration: 0.22)) {
                    self.completionPhase = .celebrating
                }
            },
            Task { @MainActor [weak self] in
                guard let self, self.completionSequenceID == sequenceID else { return }
                guard await self.sleep(for: self.microCelebrationDuration + self.messageVisibleDuration),
                      self.completionSequenceID == sequenceID else { return }

                withAnimation(.easeOut(duration: 0.2)) {
                    self.completionPhase = .transitioningToNextLevel
                }
            },
            Task { @MainActor [weak self] in
                guard let self, self.completionSequenceID == sequenceID else { return }
                guard await self.sleep(for: self.timing.completionDuration),
                      self.completionSequenceID == sequenceID else { return }

                withAnimation(.easeOut(duration: 0.25)) {
                    self.advanceToNextLevel()
                }
            }
        ]
    }

    private func completionMessage() -> String {
        guard let objectiveSummary = orderObjectiveSummary else {
            return "Order Complete! \(victoryMessageProvider())"
        }

        return "\(objectiveSummary.potionName) brewed!"
    }

    private var microCelebrationDuration: TimeInterval {
        guard timing.completionDuration > 0 else { return 0 }
        return min(0.45, timing.completionDuration * 0.3)
    }

    private var nextLevelTransitionDuration: TimeInterval {
        guard timing.completionDuration > 0 else { return 0 }
        return min(0.25, timing.completionDuration * 0.2)
    }

    private var messageVisibleDuration: TimeInterval {
        max(0, timing.completionDuration - microCelebrationDuration - nextLevelTransitionDuration)
    }

    private func awardHerbsForCompletedOrder() {
        guard currentLevelNumber > 4 else {
            lastHerbsReward = nil
            return
        }

        let reward = Self.herbsRewardPerCompletedOrder
        lastHerbsReward = reward
        herbsBalance += reward
        progressStore.herbsBalance = herbsBalance
    }

    private var isNextHintFree: Bool {
        currentLevelNumber <= 4 && hintsUsedThisLevel == 0
    }

    private var isRewardedAdInProgress: Bool {
        isRewardedHintInProgress || isRewardedBonusUnlockInProgress
    }

    private var nextHintPaymentMode: HintPaymentMode {
        if isNextHintFree {
            return .free
        }

        if herbsBalance >= Self.extraHintHerbsCost {
            return .herbs
        }

        guard featureFlags.rewardedAdsEnabled else {
            return .unavailable
        }

        return .rewardedAd
    }

    private func requestRewardedHint(_ nextHint: HintMove) {
        rewardedHintTask?.cancel()
        selectedFlaskIndex = nil
        invalidFlaskIndices.removeAll()
        isRewardedHintInProgress = true
        gameAnalyticsProvider.track(.rewardedAdStarted(
            levelNumber: currentLevelNumber,
            placement: .extraHint
        ))
        playerActionLogger.log("rewarded ad started for hint on level \(currentLevelNumber)")

        rewardedHintTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let didEarnReward = await self.rewardedAdProvider.showRewardedAd(for: .extraHint)
            guard !Task.isCancelled else { return }

            self.rewardedHintTask = nil
            self.isRewardedHintInProgress = false
            self.gameAnalyticsProvider.track(.rewardedAdCompleted(
                levelNumber: self.currentLevelNumber,
                placement: .extraHint,
                success: didEarnReward
            ))
            self.playerActionLogger.log(
                "rewarded ad completed for hint on level \(self.currentLevelNumber) success \(didEarnReward)"
            )
            guard didEarnReward else { return }

            self.applyHint(nextHint, paymentMode: .rewardedAd)
        }
    }

    private func applyHint(_ nextHint: HintMove, paymentMode: HintPaymentMode) {
        spendHintIfNeeded(paymentMode: paymentMode)
        gameFeedbackProvider.play(.hintUsed)
        gameAnalyticsProvider.track(.hintUsed(
            levelNumber: currentLevelNumber,
            payment: paymentMode.analyticsPayment
        ))
        playerActionLogger.log(
            "hint shown on level \(currentLevelNumber): flask \(nextHint.sourceIndex + 1) to flask \(nextHint.targetIndex + 1) payment \(paymentMode.logName)"
        )
        selectedFlaskIndex = nil
        invalidFlaskIndices.removeAll()
        hintMove = nextHint
    }

    private func spendHintIfNeeded(paymentMode: HintPaymentMode) {
        defer {
            hintsUsedThisLevel += 1
        }

        guard paymentMode == .herbs else { return }

        herbsBalance = max(0, herbsBalance - Self.extraHintHerbsCost)
        progressStore.herbsBalance = herbsBalance
    }

    private func targetColorProgress(for targetColor: LiquidColor) -> Int {
        gameManager.playableFlasks
            .map { flask in
                flask.colors.filter { $0 == targetColor }.count
            }
            .max() ?? 0
    }

    private func dismissOrderBanner() {
        guard isOrderBannerVisible else { return }
        isOrderBannerVisible = false
    }

    private func dismissTutorialPromptIfNeeded() {
        guard isTutorialPromptVisible else { return }

        isTutorialPromptVisible = false
        if currentLevelNumber >= 5 {
            progressStore.hasCompletedOnboarding = true
        }
    }

    func claimHerbsTutorialReward() {
        guard herbsTutorialPrompt != nil else { return }

        herbsTutorialPrompt = nil
        gameFeedbackProvider.play(.hintUsed)
        playerActionLogger.log("herbs tutorial reward claimed on level \(currentLevelNumber)")
    }

    var centersSparseTutorialRows: Bool {
        gameManager.level?.difficulty == .tutorial && gameManager.flasks.count <= 4
    }

    var tutorialMarkers: [TutorialMarker] {
        guard currentLevelNumber == 2,
              selectedFlaskIndex == gameManager.level?.initialSelectedFlaskIndex,
              gameManager.flasks.indices.contains(0),
              gameManager.flasks.indices.contains(1),
              gameManager.flasks.indices.contains(2) else {
            return []
        }

        return [
            TutorialMarker(flaskIndex: 0, kind: .correctTarget),
            TutorialMarker(flaskIndex: 2, kind: .blockedTarget)
        ]
    }

    private var requiresMandatoryHintBeforePlay: Bool {
        currentLevelNumber == 5
            && progressStore.hasSeenHerbsTutorial
            && hintsUsedThisLevel == 0
    }

    private func updateTutorialVisibility(for levelIndex: Int) {
        let levelNumber = levelIndex + 1
        if levelNumber > 5 {
            progressStore.hasCompletedOnboarding = true
        }

        isTutorialPromptVisible = Self.shouldShowTutorial(
            levelNumber: levelNumber,
            hasCompletedOnboarding: progressStore.hasCompletedOnboarding
        )
    }

    private func presentHerbsTutorialIfNeeded() {
        guard currentLevelIndex == 4,
              currentLevelNumber == 5,
              !progressStore.hasSeenHerbsTutorial else { return }

        let missingHerbs = max(0, Self.extraHintHerbsCost - herbsBalance)
        guard missingHerbs > 0 else {
            progressStore.hasSeenHerbsTutorial = true
            return
        }

        herbsBalance += missingHerbs
        progressStore.herbsBalance = herbsBalance
        progressStore.hasSeenHerbsTutorial = true
        herbsTutorialPrompt = HerbsTutorialPrompt(herbsAmount: missingHerbs)
        playerActionLogger.log("herbs tutorial reward shown level 5 amount \(missingHerbs)")
    }

    private nonisolated static func shouldShowTutorial(
        levelNumber: Int,
        hasCompletedOnboarding: Bool
    ) -> Bool {
        !hasCompletedOnboarding && (1...5).contains(levelNumber)
    }

    private func bindGameManager() {
        cancellables.removeAll()

        gameManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func cancelScheduledWork() {
        pourAnimationTask?.cancel()
        pourAnimationTask = nil
        invalidFeedbackTask?.cancel()
        invalidFeedbackTask = nil
        rewardedHintTask?.cancel()
        rewardedHintTask = nil
        isRewardedHintInProgress = false
        rewardedBonusUnlockTask?.cancel()
        rewardedBonusUnlockTask = nil
        isRewardedBonusUnlockInProgress = false
        permanentBonusUnlockTask?.cancel()
        permanentBonusUnlockTask = nil
        isPermanentBonusUnlockInProgress = false
        cancelCompletionTasks()
    }

    private func cancelCompletionTasks() {
        completionTasks.forEach { $0.cancel() }
        completionTasks.removeAll()
    }

    private func sleep(for duration: TimeInterval) async -> Bool {
        guard duration > 0 else {
            return !Task.isCancelled
        }

        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
