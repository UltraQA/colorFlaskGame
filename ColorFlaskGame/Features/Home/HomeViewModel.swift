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

enum RoundState: Equatable {
    case playing
    case completing
}

final class HomeViewModel: ObservableObject {
    private static let bonusFlaskPurchaseKey = "waterSort.bonusFlask.isPermanentlyUnlocked"
    private static let currentLevelIndexKey = "waterSort.progress.currentLevelIndex"

    @Published private(set) var gameManager: GameManager
    @Published private(set) var selectedFlaskIndex: Int?
    @Published private(set) var pourAnimation: PourAnimation?
    @Published private(set) var hintMove: HintMove?
    @Published private(set) var roundState: RoundState = .playing
    @Published private(set) var moves = 0
    @Published private(set) var isBonusFlaskPermanentlyUnlocked: Bool
    @Published private(set) var currentLevelIndex: Int

    private var cancellables: Set<AnyCancellable> = []
    private var history: [[Flask]] = []
    private let levelRepository: any LevelRepository
    private let pourAnimationDuration: TimeInterval = 0.55
    private let completionDuration: TimeInterval = 1.15

    init(
        gameManager: GameManager? = nil,
        levelRepository: any LevelRepository = HandcraftedLevelRepository(),
        currentLevelIndex: Int = UserDefaults.standard.integer(forKey: currentLevelIndexKey),
        isBonusFlaskPermanentlyUnlocked: Bool = UserDefaults.standard.bool(forKey: bonusFlaskPurchaseKey)
    ) {
        self.levelRepository = levelRepository
        self.currentLevelIndex = currentLevelIndex
        self.isBonusFlaskPermanentlyUnlocked = isBonusFlaskPermanentlyUnlocked
        self.gameManager = gameManager ?? .makeInitialLevel(
            levelIndex: currentLevelIndex,
            levelRepository: levelRepository,
            isBonusFlaskUnlocked: isBonusFlaskPermanentlyUnlocked
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
        guard gameManager.flasks.indices.contains(index),
              gameManager.flasks[index].isPlayable,
              canInteractWithBoard else { return }

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
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? sourceIndex : index
        }
    }

    func undo() {
        guard canUndo, let previousFlasks = history.popLast() else { return }

        selectedFlaskIndex = nil
        hintMove = nil
        gameManager.restore(flasks: previousFlasks)
        moves = max(0, moves - 1)
        objectWillChange.send()
    }

    func showHint() {
        guard pourAnimation == nil, let plan = gameManager.firstValidMove() else { return }

        selectedFlaskIndex = nil
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
        roundState = .playing
        history.removeAll()
        moves = 0
        currentLevelIndex = levelIndex
        UserDefaults.standard.set(levelIndex, forKey: Self.currentLevelIndexKey)
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
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    func unlockBonusFlaskPermanently() {
        guard roundState == .playing else { return }
        isBonusFlaskPermanentlyUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.bonusFlaskPurchaseKey)
        gameManager.unlockBonusFlaskForCurrentRound()
        objectWillChange.send()
    }

    private func animatePour(_ plan: PourPlan) {
        selectedFlaskIndex = nil
        hintMove = nil
        history.append(gameManager.flasks)
        pourAnimation = PourAnimation(
            sourceIndex: plan.sourceIndex,
            targetIndex: plan.targetIndex,
            color: plan.color
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + pourAnimationDuration) { [weak self] in
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

    private func completeRoundIfNeeded() {
        guard gameManager.isRoundCompleted, roundState == .playing else { return }

        selectedFlaskIndex = nil
        hintMove = nil
        roundState = .completing

        DispatchQueue.main.asyncAfter(deadline: .now() + completionDuration) { [weak self] in
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
