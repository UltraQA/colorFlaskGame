import SwiftUI
import XCTest
@testable import ColorFlaskGame

@MainActor
final class HomeViewModelTests: XCTestCase {
    private let red = Color.red
    private let green = Color.green
    private let blue = Color.blue

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: Self.testSuiteName)
        super.tearDown()
    }

    func testLockedBonusFlaskTapShowsUnlockPrompt() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(),
                Flask(kind: .bonus, isUnlocked: false)
            ]
        )

        viewModel.handleFlaskTap(at: 2)

        XCTAssertEqual(viewModel.bonusUnlockPrompt, BonusUnlockPrompt(flaskIndex: 2))
        XCTAssertNil(viewModel.selectedFlaskIndex)
    }

    func testUnlockBonusFlaskForCurrentRoundClearsPromptAndUnlocksFlask() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ]
        )

        viewModel.handleFlaskTap(at: 1)
        viewModel.unlockBonusFlaskForCurrentRound()

        XCTAssertNil(viewModel.bonusUnlockPrompt)
        XCTAssertTrue(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertFalse(viewModel.isBonusFlaskPermanentlyUnlocked)
    }

    func testUnlockBonusFlaskPermanentlyPersistsChoice() {
        let defaults = testUserDefaults
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            userDefaults: defaults
        )

        viewModel.unlockBonusFlaskPermanently()

        XCTAssertTrue(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertTrue(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertTrue(defaults.bool(forKey: "waterSort.bonusFlask.isPermanentlyUnlocked"))
    }

    func testProgressStoreSeedsInitialLevelAndPermanentBonusUnlock() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 4,
            isBonusFlaskPermanentlyUnlocked: true
        )

        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertEqual(viewModel.currentLevelIndex, 4)
        XCTAssertTrue(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isPlayable == true)
    }

    func testProgressStorePersistsLevelAdvanceAndPermanentBonusUnlock() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        viewModel.advanceToNextLevel()
        viewModel.unlockBonusFlaskPermanently()

        XCTAssertEqual(progressStore.currentLevelIndex, 1)
        XCTAssertTrue(progressStore.isBonusFlaskPermanentlyUnlocked)
    }

    func testValidTapFlowAnimatesPourAndEnablesUndo() async {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red, red]),
                Flask(colors: [red])
            ]
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertNil(viewModel.selectedFlaskIndex)
        XCTAssertNil(viewModel.pourAnimation)
        XCTAssertEqual(viewModel.moves, 1)
        XCTAssertTrue(viewModel.canUndo)
        XCTAssertTrue(viewModel.gameManager.flasks[0].isEmpty)
        XCTAssertEqual(viewModel.gameManager.flasks[1].colors, [red, red, red])
    }

    func testVictoryMessageAppearsWhenRoundCompletes() async {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [red, red, red])
            ],
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            ),
            victoryMessageProvider: { "Potion Perfect!" }
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.completionPhase, .resolvingWin)
        XCTAssertEqual(viewModel.victoryMessage, "Potion Perfect!")
    }

    func testCompletionFlowAdvancesFromResolvingToCelebrating() async {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [red, red, red])
            ],
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 0.5,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork(nanoseconds: 220_000_000)

        XCTAssertEqual(viewModel.completionPhase, .celebrating)
    }

    func testUndoRestoresPreviousFlasksAfterValidMove() async {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [blue]),
                Flask(colors: [])
            ]
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()
        viewModel.undo()

        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertFalse(viewModel.canUndo)
    }

    func testInvalidMoveDoesNotEnterUndoHistory() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [green])
            ]
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)

        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertEqual(viewModel.invalidMoveCount, 1)
        XCTAssertEqual(viewModel.selectedFlaskIndex, 1)
    }

    func testHintHighlightsFirstValidMoveWithoutPouring() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ]
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.showHint()

        XCTAssertEqual(viewModel.hintMove, HintMove(sourceIndex: 0, targetIndex: 1))
        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
        XCTAssertEqual(viewModel.moves, 0)
    }

    func testStartNewGameClearsTemporaryBonusUnlockAndHistory() async {
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: .immediate
        )

        viewModel.unlockBonusFlaskForCurrentRound()
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isPlayable == true)

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()
        XCTAssertTrue(viewModel.canUndo)

        viewModel.startNewGame()

        XCTAssertFalse(viewModel.canUndo)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isBonus == true)
        XCTAssertFalse(viewModel.gameManager.flasks.last?.isPlayable == true)
    }

    func testStartNewGameCancelsPendingPourAnimation() async {
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0.25,
                completionDuration: 0,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        XCTAssertNotNil(viewModel.pourAnimation)

        viewModel.startNewGame()
        let resetFlasks = viewModel.gameManager.flasks
        await waitForScheduledMainQueueWork(nanoseconds: 350_000_000)

        XCTAssertEqual(viewModel.gameManager.flasks, resetFlasks)
        XCTAssertNil(viewModel.pourAnimation)
        XCTAssertEqual(viewModel.moves, 0)
    }

    func testStartNewGameCancelsPendingCompletionAdvance() async {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [red, red, red])
            ],
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 0.35,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()
        XCTAssertEqual(viewModel.completionPhase, .resolvingWin)

        viewModel.startNewGame()
        await waitForScheduledMainQueueWork(nanoseconds: 450_000_000)

        XCTAssertEqual(viewModel.currentLevelIndex, 0)
        XCTAssertEqual(viewModel.completionPhase, .playing)
    }

    private func makeViewModel(
        flasks: [Flask],
        userDefaults: UserDefaults? = nil,
        timing: HomeViewModelTiming = .immediate,
        victoryMessageProvider: @escaping () -> String = { "Fantastic!" }
    ) -> HomeViewModel {
        HomeViewModel(
            gameManager: GameManager(flasks: flasks),
            userDefaults: userDefaults ?? testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: timing,
            victoryMessageProvider: victoryMessageProvider
        )
    }

    private func waitForScheduledMainQueueWork(nanoseconds: UInt64 = 50_000_000) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private var testUserDefaults: UserDefaults {
        let defaults = UserDefaults(suiteName: Self.testSuiteName)!
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        return defaults
    }

    private static let testSuiteName = "ColorFlaskGame.HomeViewModelTests"
}

private struct SingleLevelRepository: LevelRepository {
    let levels = [
        Level(
            id: 1,
            difficulty: .tutorial,
            filledFlasks: [
                Flask(colors: [.red]),
                Flask(colors: [])
            ],
            availableEmptyFlaskCount: 0,
            hasLockedBonusFlask: true
        )
    ]

    func level(at index: Int) -> Level {
        levels[index % levels.count]
    }
}

private final class SpyProgressStore: ProgressStore {
    var currentLevelIndex: Int
    var isBonusFlaskPermanentlyUnlocked: Bool

    init(currentLevelIndex: Int, isBonusFlaskPermanentlyUnlocked: Bool) {
        self.currentLevelIndex = currentLevelIndex
        self.isBonusFlaskPermanentlyUnlocked = isBonusFlaskPermanentlyUnlocked
    }
}
