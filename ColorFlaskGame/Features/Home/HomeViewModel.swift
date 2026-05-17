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
    nonisolated static let victoryMessages = [
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
    @Published private(set) var completionPhase: LevelCompletionPhase = .playing
    @Published private(set) var moves = 0
    @Published private(set) var isBonusFlaskPermanentlyUnlocked: Bool
    @Published private(set) var currentLevelIndex: Int
    @Published private(set) var victoryMessage: String?

    private var cancellables: Set<AnyCancellable> = []
    private var history: [[Flask]] = []
    private let levelRepository: any LevelRepository
    private var progressStore: any ProgressStore
    private let timing: HomeViewModelTiming
    private let victoryMessageProvider: () -> String
    private var completionSequenceID = 0
    private var pourAnimationTask: Task<Void, Never>?
    private var invalidFeedbackTask: Task<Void, Never>?
    private var completionTasks: [Task<Void, Never>] = []

    init(
        gameManager: GameManager? = nil,
        levelRepository: any LevelRepository = HandcraftedLevelRepository(),
        progressStore: (any ProgressStore)? = nil,
        userDefaults: UserDefaults = .standard,
        currentLevelIndex: Int? = nil,
        isBonusFlaskPermanentlyUnlocked: Bool? = nil,
        timing: HomeViewModelTiming = .live,
        victoryMessageProvider: @escaping () -> String = {
            HomeViewModel.victoryMessages.randomElement() ?? "Fantastic!"
        }
    ) {
        self.levelRepository = levelRepository
        let resolvedProgressStore = progressStore ?? UserDefaultsProgressStore(userDefaults: userDefaults)
        self.progressStore = resolvedProgressStore
        self.timing = timing
        self.victoryMessageProvider = victoryMessageProvider
        let resolvedLevelIndex = currentLevelIndex ?? resolvedProgressStore.currentLevelIndex
        let resolvedBonusUnlock = isBonusFlaskPermanentlyUnlocked ?? resolvedProgressStore.isBonusFlaskPermanentlyUnlocked
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
        completionPhase.isPlaying && !history.isEmpty && pourAnimation == nil
    }

    var canShowHint: Bool {
        completionPhase.isPlaying
            && pourAnimation == nil
            && !gameManager.isRoundCompleted
            && gameManager.firstValidMove() != nil
    }

    var canInteractWithBoard: Bool {
        completionPhase.isPlaying && pourAnimation == nil
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
        cancelScheduledWork()
        selectedFlaskIndex = nil
        pourAnimation = nil
        hintMove = nil
        bonusUnlockPrompt = nil
        invalidFlaskIndices.removeAll()
        completionPhase = .playing
        victoryMessage = nil
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
        bindGameManager()
        objectWillChange.send()
    }

    func unlockBonusFlaskForCurrentRound() {
        guard completionPhase.isPlaying else { return }
        bonusUnlockPrompt = nil
        selectedFlaskIndex = nil
        hintMove = nil
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    func unlockBonusFlaskPermanently() {
        guard completionPhase.isPlaying else { return }
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
        victoryMessage = victoryMessageProvider()
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
