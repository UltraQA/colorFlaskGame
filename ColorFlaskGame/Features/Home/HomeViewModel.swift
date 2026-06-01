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

protocol RewardedAdProviding {
    func showRewardedAd(for placement: RewardedAdPlacement) async -> Bool
}

struct StubRewardedAdProvider: RewardedAdProviding {
    func showRewardedAd(for placement: RewardedAdPlacement) async -> Bool {
        true
    }
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
    @Published private(set) var isOrderBannerVisible = true
    @Published private(set) var isTutorialPromptVisible: Bool
    @Published var resetConfirmationPrompt: ResetConfirmationPrompt?
    @Published var herbsTutorialPrompt: HerbsTutorialPrompt?

    private var cancellables: Set<AnyCancellable> = []
    private var history: [[Flask]] = []
    private let levelRepository: any LevelRepository
    private var progressStore: any ProgressStore
    private let rewardedAdProvider: any RewardedAdProviding
    private let gameFeedbackProvider: any GameFeedbackProviding
    private let timing: HomeViewModelTiming
    private let victoryMessageProvider: () -> String
    private var completionSequenceID = 0
    private var pourAnimationTask: Task<Void, Never>?
    private var invalidFeedbackTask: Task<Void, Never>?
    private var rewardedHintTask: Task<Void, Never>?
    private var rewardedBonusUnlockTask: Task<Void, Never>?
    private var completionTasks: [Task<Void, Never>] = []

    init(
        gameManager: GameManager? = nil,
        levelRepository: any LevelRepository = HandcraftedLevelRepository(),
        progressStore: (any ProgressStore)? = nil,
        userDefaults: UserDefaults = .standard,
        currentLevelIndex: Int? = nil,
        isBonusFlaskPermanentlyUnlocked: Bool? = nil,
        rewardedAdProvider: any RewardedAdProviding = StubRewardedAdProvider(),
        gameFeedbackProvider: (any GameFeedbackProviding)? = nil,
        timing: HomeViewModelTiming = .live,
        victoryMessageProvider: @escaping () -> String = {
            HomeViewModel.victoryMessages.randomElement() ?? "Fantastic!"
        }
    ) {
        self.levelRepository = levelRepository
        let resolvedProgressStore = progressStore ?? UserDefaultsProgressStore(userDefaults: userDefaults)
        self.progressStore = resolvedProgressStore
        self.rewardedAdProvider = rewardedAdProvider
        self.gameFeedbackProvider = gameFeedbackProvider ?? NoOpGameFeedbackProvider()
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
        guard isTutorialPromptVisible, let plan = gameManager.firstValidMove() else { return nil }
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
            && !gameManager.isRoundCompleted
            && gameManager.firstValidMove() != nil
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
                bonusUnlockPrompt = BonusUnlockPrompt(flaskIndex: index)
            }
            return
        }

        hintMove = nil

        guard let sourceIndex = selectedFlaskIndex else {
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? nil : index
            gameFeedbackProvider.play(selectedFlaskIndex == nil ? .uiTap : .flaskSelect)
            return
        }

        guard sourceIndex != index else {
            selectedFlaskIndex = nil
            gameFeedbackProvider.play(.uiTap)
            return
        }

        switch gameManager.pourPlan(from: sourceIndex, to: index) {
        case let .success(plan):
            animatePour(plan)
        case .failure:
            showInvalidMoveFeedback(sourceIndex: sourceIndex, targetIndex: index)
            selectedFlaskIndex = sourceIndex
        }
    }

    func undo() {
        guard canUndo, let previousFlasks = history.popLast() else { return }

        gameFeedbackProvider.play(.undo)
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        gameManager.restore(flasks: previousFlasks)
        moves = max(0, moves - 1)
        objectWillChange.send()
    }

    func showHint() {
        guard pourAnimation == nil, !isRewardedAdInProgress, let plan = gameManager.firstValidMove() else { return }
        guard currentLevelNumber != 5 || progressStore.hasSeenHerbsTutorial else { return }

        dismissOrderBanner()
        dismissTutorialPromptIfNeeded()
        let nextHint = HintMove(sourceIndex: plan.sourceIndex, targetIndex: plan.targetIndex)
        guard hintMove != nextHint else { return }

        let paymentMode = nextHintPaymentMode
        switch paymentMode {
        case .rewardedAd:
            requestRewardedHint(nextHint)
        case .free, .herbs:
            applyHint(nextHint, paymentMode: paymentMode)
        }
    }

    func startNewGame() {
        loadLevel(at: currentLevelIndex)
    }

    func beginCurrentOrder() {
        presentHerbsTutorialIfNeeded()
    }

    func requestReset() {
        guard canInteractWithBoard else { return }

        dismissOrderBanner()
        dismissTutorialPromptIfNeeded()
        guard moves > 0 || currentLevelNumber >= Level.lockedBonusIntroductionLevelID else {
            startNewGame()
            return
        }

        resetConfirmationPrompt = ResetConfirmationPrompt()
    }

    func confirmReset() {
        resetConfirmationPrompt = nil
        gameFeedbackProvider.play(.reset)
        startNewGame()
    }

    func cancelReset() {
        resetConfirmationPrompt = nil
    }

    func resetProgressForTesting() {
        resetProgress()
    }

    func resetProgress() {
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
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    func requestBonusFlaskUnlockForCurrentRound() {
        guard completionPhase.isPlaying, !isRewardedAdInProgress else { return }

        rewardedBonusUnlockTask?.cancel()
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        isRewardedBonusUnlockInProgress = true

        rewardedBonusUnlockTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let didEarnReward = await self.rewardedAdProvider.showRewardedAd(for: .bonusFlask)
            guard !Task.isCancelled else { return }

            self.rewardedBonusUnlockTask = nil
            self.isRewardedBonusUnlockInProgress = false
            guard didEarnReward else { return }

            self.unlockBonusFlaskForCurrentRound()
        }
    }

    func unlockBonusFlaskPermanently() {
        guard completionPhase.isPlaying else { return }
        gameFeedbackProvider.play(.uiTap)
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        isBonusFlaskPermanentlyUnlocked = true
        progressStore.isBonusFlaskPermanentlyUnlocked = true
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    private func animatePour(_ plan: PourPlan) {
        pourAnimationTask?.cancel()
        gameFeedbackProvider.play(.validPour)
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
                }
                self.pourAnimation = nil
            }

            self.completeRoundIfNeeded()
        }
    }

    private func showInvalidMoveFeedback(sourceIndex: Int, targetIndex: Int) {
        invalidFeedbackTask?.cancel()
        gameFeedbackProvider.play(.invalidMove)
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

        return .rewardedAd
    }

    private func requestRewardedHint(_ nextHint: HintMove) {
        rewardedHintTask?.cancel()
        selectedFlaskIndex = nil
        invalidFlaskIndices.removeAll()
        isRewardedHintInProgress = true

        rewardedHintTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let didEarnReward = await self.rewardedAdProvider.showRewardedAd(for: .extraHint)
            guard !Task.isCancelled else { return }

            self.rewardedHintTask = nil
            self.isRewardedHintInProgress = false
            guard didEarnReward else { return }

            self.applyHint(nextHint, paymentMode: .rewardedAd)
        }
    }

    private func applyHint(_ nextHint: HintMove, paymentMode: HintPaymentMode) {
        spendHintIfNeeded(paymentMode: paymentMode)
        gameFeedbackProvider.play(.hintUsed)
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
