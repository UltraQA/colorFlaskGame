import SwiftUI
import Combine

struct PourAnimation: Identifiable, Equatable {
    let id = UUID()
    let sourceIndex: Int
    let targetIndex: Int
    let color: Color
}

struct HintMove: Equatable {
    let sourceIndex: Int
    let targetIndex: Int
}

struct BonusUnlockPrompt: Identifiable, Equatable {
    let flaskIndex: Int

    var id: Int {
        flaskIndex
    }
}

enum RoundState: Equatable {
    case playing
    case completing
}

struct HomeViewModelTiming: Equatable {
    let pourAnimationDuration: TimeInterval
    let completionDuration: TimeInterval
    let invalidFeedbackDuration: TimeInterval

    static let live = HomeViewModelTiming(
        pourAnimationDuration: 0.55,
        completionDuration: 1.15,
        invalidFeedbackDuration: 0.32
    )

    static let immediate = HomeViewModelTiming(
        pourAnimationDuration: 0,
        completionDuration: 0,
        invalidFeedbackDuration: 0
    )
}

final class HomeViewModel: ObservableObject {
    private static let bonusFlaskPurchaseKey = "waterSort.bonusFlask.isPermanentlyUnlocked"
    private static let currentLevelIndexKey = "waterSort.progress.currentLevelIndex"
    static let victoryMessages = [
        "Fantastic!",
        "Yaaay!",
        "You did it!",
        "Let's go!",
        "Easy Peasy!",
        "Potion Perfect!",
        "Well brewed!"
    ]

    @Published private(set) var gameManager: GameManager
    @Published private(set) var selectedFlaskIndex: Int?
    @Published private(set) var pourAnimation: PourAnimation?
    @Published private(set) var hintMove: HintMove?
    @Published private(set) var invalidFlaskIndices: Set<Int> = []
    @Published private(set) var invalidMoveCount = 0
    @Published var bonusUnlockPrompt: BonusUnlockPrompt?
    @Published private(set) var roundState: RoundState = .playing
    @Published private(set) var moves = 0
    @Published private(set) var isBonusFlaskPermanentlyUnlocked: Bool
    @Published private(set) var currentLevelIndex: Int
    @Published private(set) var victoryMessage: String?

    private var cancellables: Set<AnyCancellable> = []
    private var history: [[Flask]] = []
    private let levelRepository: any LevelRepository
    private let userDefaults: UserDefaults
    private let timing: HomeViewModelTiming
    private let victoryMessageProvider: () -> String

    init(
        gameManager: GameManager? = nil,
        levelRepository: any LevelRepository = HandcraftedLevelRepository(),
        userDefaults: UserDefaults = .standard,
        currentLevelIndex: Int? = nil,
        isBonusFlaskPermanentlyUnlocked: Bool? = nil,
        timing: HomeViewModelTiming = .live,
        victoryMessageProvider: @escaping () -> String = {
            HomeViewModel.victoryMessages.randomElement() ?? "Fantastic!"
        }
    ) {
        self.levelRepository = levelRepository
        self.userDefaults = userDefaults
        self.timing = timing
        self.victoryMessageProvider = victoryMessageProvider
        let resolvedLevelIndex = currentLevelIndex ?? userDefaults.integer(forKey: Self.currentLevelIndexKey)
        let resolvedBonusUnlock = isBonusFlaskPermanentlyUnlocked ?? userDefaults.bool(forKey: Self.bonusFlaskPurchaseKey)
        self.currentLevelIndex = resolvedLevelIndex
        self.isBonusFlaskPermanentlyUnlocked = resolvedBonusUnlock
        self.gameManager = gameManager ?? .makeInitialLevel(
            levelIndex: resolvedLevelIndex,
            levelRepository: levelRepository,
            isBonusFlaskUnlocked: resolvedBonusUnlock
        )
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

    var canUndo: Bool {
        roundState == .playing && !history.isEmpty && pourAnimation == nil
    }

    var canShowHint: Bool {
        roundState == .playing
            && pourAnimation == nil
            && !gameManager.isRoundCompleted
            && gameManager.firstValidMove() != nil
    }

    var canInteractWithBoard: Bool {
        roundState == .playing && pourAnimation == nil
    }

    func handleFlaskTap(at index: Int) {
        guard gameManager.flasks.indices.contains(index), canInteractWithBoard else { return }

        let flask = gameManager.flasks[index]

        guard flask.isPlayable else {
            if flask.isBonus {
                bonusUnlockPrompt = BonusUnlockPrompt(flaskIndex: index)
            }
            return
        }

        hintMove = nil

        guard let sourceIndex = selectedFlaskIndex else {
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? nil : index
            return
        }

        guard sourceIndex != index else {
            selectedFlaskIndex = nil
            return
        }

        switch gameManager.pourPlan(from: sourceIndex, to: index) {
        case let .success(plan):
            animatePour(plan)
        case .failure:
            showInvalidMoveFeedback(sourceIndex: sourceIndex, targetIndex: index)
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? sourceIndex : index
        }
    }

    func undo() {
        guard canUndo, let previousFlasks = history.popLast() else { return }

        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        gameManager.restore(flasks: previousFlasks)
        moves = max(0, moves - 1)
        objectWillChange.send()
    }

    func showHint() {
        guard pourAnimation == nil, let plan = gameManager.firstValidMove() else { return }

        selectedFlaskIndex = nil
        invalidFlaskIndices.removeAll()
        hintMove = HintMove(sourceIndex: plan.sourceIndex, targetIndex: plan.targetIndex)
    }

    func startNewGame() {
        loadLevel(at: currentLevelIndex)
    }

    func advanceToNextLevel() {
        loadLevel(at: currentLevelIndex + 1)
    }

    private func loadLevel(at levelIndex: Int) {
        selectedFlaskIndex = nil
        pourAnimation = nil
        hintMove = nil
        bonusUnlockPrompt = nil
        invalidFlaskIndices.removeAll()
        roundState = .playing
        victoryMessage = nil
        history.removeAll()
        moves = 0
        currentLevelIndex = levelIndex
        userDefaults.set(levelIndex, forKey: Self.currentLevelIndexKey)
        gameManager = .makeInitialLevel(
            levelIndex: levelIndex,
            levelRepository: levelRepository,
            isBonusFlaskUnlocked: isBonusFlaskPermanentlyUnlocked
        )
        bindGameManager()
        objectWillChange.send()
    }

    func unlockBonusFlaskForCurrentRound() {
        guard roundState == .playing else { return }
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    func unlockBonusFlaskPermanently() {
        guard roundState == .playing else { return }
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        isBonusFlaskPermanentlyUnlocked = true
        userDefaults.set(true, forKey: Self.bonusFlaskPurchaseKey)
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    private func animatePour(_ plan: PourPlan) {
        selectedFlaskIndex = nil
        hintMove = nil
        invalidFlaskIndices.removeAll()
        history.append(gameManager.flasks)
        pourAnimation = PourAnimation(
            sourceIndex: plan.sourceIndex,
            targetIndex: plan.targetIndex,
            color: plan.color
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + timing.pourAnimationDuration) { [weak self] in
            guard let self else { return }

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
        invalidFlaskIndices = [sourceIndex, targetIndex]
        withAnimation(.linear(duration: timing.invalidFeedbackDuration)) {
            invalidMoveCount += 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timing.invalidFeedbackDuration) { [weak self] in
            self?.invalidFlaskIndices.removeAll()
        }
    }

    private func completeRoundIfNeeded() {
        guard gameManager.isRoundCompleted, roundState == .playing else { return }

        selectedFlaskIndex = nil
        hintMove = nil
        victoryMessage = victoryMessageProvider()
        roundState = .completing

        DispatchQueue.main.asyncAfter(deadline: .now() + timing.completionDuration) { [weak self] in
            guard let self, self.roundState == .completing else { return }

            withAnimation(.snappy(duration: 0.35)) {
                self.advanceToNextLevel()
            }
        }
    }

    private func bindGameManager() {
        cancellables.removeAll()

        gameManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
