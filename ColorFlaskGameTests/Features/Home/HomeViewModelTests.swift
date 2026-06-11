import XCTest
@testable import ColorFlaskGame

@MainActor
final class HomeViewModelTests: XCTestCase {
    private let red = LiquidColor.red
    private let green = LiquidColor.green
    private let blue = LiquidColor.blue
    private let yellow = LiquidColor.yellow

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: Self.testSuiteName)
        super.tearDown()
    }

    func testLockedBonusFlaskTapShowsUnlockPrompt() {
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            gameAnalyticsProvider: analyticsProvider
        )

        viewModel.handleFlaskTap(at: 2)

        XCTAssertEqual(viewModel.bonusUnlockPrompt, BonusUnlockPrompt(flaskIndex: 2))
        XCTAssertNil(viewModel.selectedFlaskIndex)
        XCTAssertEqual(analyticsProvider.events, [.bonusFlaskPromptShown(levelNumber: 1)])
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

    func testRewardedBonusUnlockOpensFlaskWhenRewardSucceeds() async {
        let rewardedAdProvider = SpyRewardedAdProvider(result: true)
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider
        )

        viewModel.handleFlaskTap(at: 1)
        viewModel.requestBonusFlaskUnlockForCurrentRound()

        XCTAssertTrue(viewModel.isRewardedBonusUnlockInProgress)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.isRewardedBonusUnlockInProgress)
        XCTAssertNil(viewModel.bonusUnlockPrompt)
        XCTAssertTrue(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)
        XCTAssertEqual(rewardedAdProvider.placements, [.bonusFlask])
        XCTAssertEqual(analyticsProvider.events, [
            .bonusFlaskPromptShown(levelNumber: 1),
            .bonusFlaskUnlockStarted(levelNumber: 1, method: .rewardedAd),
            .rewardedAdStarted(levelNumber: 1, placement: .bonusFlask),
            .rewardedAdCompleted(levelNumber: 1, placement: .bonusFlask, success: true),
            .bonusFlaskUnlockCompleted(levelNumber: 1, method: .rewardedAd, success: true)
        ])
    }

    func testRewardedBonusUnlockKeepsFlaskLockedWhenRewardFails() async {
        let rewardedAdProvider = SpyRewardedAdProvider(result: false)
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider
        )

        viewModel.handleFlaskTap(at: 1)
        viewModel.requestBonusFlaskUnlockForCurrentRound()
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.isRewardedBonusUnlockInProgress)
        XCTAssertEqual(viewModel.bonusUnlockPrompt, BonusUnlockPrompt(flaskIndex: 1))
        XCTAssertFalse(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)
        XCTAssertEqual(rewardedAdProvider.placements, [.bonusFlask])
        XCTAssertEqual(analyticsProvider.events, [
            .bonusFlaskPromptShown(levelNumber: 1),
            .bonusFlaskUnlockStarted(levelNumber: 1, method: .rewardedAd),
            .rewardedAdStarted(levelNumber: 1, placement: .bonusFlask),
            .rewardedAdCompleted(levelNumber: 1, placement: .bonusFlask, success: false),
            .bonusFlaskUnlockCompleted(levelNumber: 1, method: .rewardedAd, success: false)
        ])
    }

    func testRewardedBonusUnlockDoesNothingWhenAdsAreDisabled() async {
        let rewardedAdProvider = SpyRewardedAdProvider(result: true)
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            rewardedAdProvider: rewardedAdProvider,
            featureFlags: GameFeatureFlags(
                rewardedAdsEnabled: false,
                permanentBonusFlaskPurchaseEnabled: false
            )
        )

        viewModel.handleFlaskTap(at: 1)
        viewModel.requestBonusFlaskUnlockForCurrentRound()
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.isRewardedBonusUnlockInProgress)
        XCTAssertEqual(viewModel.bonusUnlockPrompt, BonusUnlockPrompt(flaskIndex: 1))
        XCTAssertFalse(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertEqual(rewardedAdProvider.showCount, 0)
    }

    func testUnlockBonusFlaskPermanentlyPersistsChoice() async {
        let defaults = testUserDefaults
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            userDefaults: defaults,
            gameAnalyticsProvider: analyticsProvider,
            featureFlags: .allEnabled
        )

        viewModel.unlockBonusFlaskPermanently()
        XCTAssertTrue(viewModel.isPermanentBonusUnlockInProgress)
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.isPermanentBonusUnlockInProgress)
        XCTAssertTrue(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertTrue(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertTrue(defaults.bool(forKey: "waterSort.bonusFlask.isPermanentlyUnlocked"))
        XCTAssertEqual(analyticsProvider.events, [
            .bonusFlaskUnlockStarted(levelNumber: 1, method: .permanentPurchase),
            .purchaseStarted(levelNumber: 1, product: .permanentBonusFlask),
            .purchaseCompleted(levelNumber: 1, product: .permanentBonusFlask, result: .purchased),
            .bonusFlaskUnlockCompleted(levelNumber: 1, method: .permanentPurchase, success: true)
        ])
    }

    func testPermanentBonusUnlockKeepsFlaskLockedWhenPurchaseFails() async {
        let defaults = testUserDefaults
        let analyticsProvider = SpyGameAnalyticsProvider()
        let purchaseProvider = SpyBonusFlaskPurchaseProvider(result: .failed)
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            userDefaults: defaults,
            bonusFlaskPurchaseProvider: purchaseProvider,
            gameAnalyticsProvider: analyticsProvider,
            featureFlags: .allEnabled
        )

        viewModel.handleFlaskTap(at: 1)
        viewModel.unlockBonusFlaskPermanently()
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.isPermanentBonusUnlockInProgress)
        XCTAssertFalse(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertFalse(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertEqual(viewModel.bonusUnlockPrompt, BonusUnlockPrompt(flaskIndex: 1))
        XCTAssertFalse(defaults.bool(forKey: "waterSort.bonusFlask.isPermanentlyUnlocked"))
        XCTAssertEqual(purchaseProvider.products, [.permanentBonusFlask])
        XCTAssertEqual(analyticsProvider.events, [
            .bonusFlaskPromptShown(levelNumber: 1),
            .bonusFlaskUnlockStarted(levelNumber: 1, method: .permanentPurchase),
            .purchaseStarted(levelNumber: 1, product: .permanentBonusFlask),
            .purchaseCompleted(levelNumber: 1, product: .permanentBonusFlask, result: .failed),
            .bonusFlaskUnlockCompleted(levelNumber: 1, method: .permanentPurchase, success: false)
        ])
    }

    func testPermanentBonusUnlockDoesNothingWhenPurchaseFeatureIsDisabled() {
        let defaults = testUserDefaults
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, isUnlocked: false)
            ],
            userDefaults: defaults
        )

        viewModel.unlockBonusFlaskPermanently()

        XCTAssertFalse(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertFalse(viewModel.gameManager.flasks[1].isPlayable)
        XCTAssertFalse(defaults.bool(forKey: "waterSort.bonusFlask.isPermanentlyUnlocked"))
    }

    func testProgressStoreSeedsInitialLevelAndPermanentBonusUnlock() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 4,
            isBonusFlaskPermanentlyUnlocked: true,
            herbsBalance: 24,
            hasCompletedOnboarding: true
        )

        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            featureFlags: .allEnabled,
            timing: .immediate
        )

        XCTAssertEqual(viewModel.currentLevelIndex, 4)
        XCTAssertTrue(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertEqual(viewModel.herbsBalance, 24)
        XCTAssertFalse(viewModel.isTutorialPromptVisible)
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isPlayable == true)
    }

    func testIntroSeenStatePersistsWithoutCompletingGameplayOnboarding() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertFalse(viewModel.hasSeenIntro)
        XCTAssertTrue(viewModel.isTutorialPromptVisible)

        viewModel.markIntroSeen()

        XCTAssertTrue(viewModel.hasSeenIntro)
        XCTAssertTrue(progressStore.hasSeenIntro)
        XCTAssertFalse(progressStore.hasCompletedOnboarding)
        XCTAssertTrue(viewModel.isTutorialPromptVisible)
    }

    func testAppFlowStartsAtMainMenuAfterIntroWasSeen() {
        XCTAssertEqual(AppFlow.initial(hasSeenIntro: false), .intro)
        XCTAssertEqual(AppFlow.initial(hasSeenIntro: true), .mainMenu)
    }

    func testProductionFeatureFlagsHideDebugLevelJump() {
        XCTAssertTrue(GameFeatureFlags.alpha.debugLevelJumpEnabled)
        XCTAssertTrue(GameFeatureFlags.allEnabled.debugLevelJumpEnabled)
        XCTAssertFalse(GameFeatureFlags.production.debugLevelJumpEnabled)
    }

    func testProgressStorePersistsLevelAdvanceAndPermanentBonusUnlock() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            featureFlags: .allEnabled,
            timing: .immediate
        )

        viewModel.advanceToNextLevel()
        viewModel.unlockBonusFlaskPermanently()
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(progressStore.currentLevelIndex, 1)
        XCTAssertTrue(progressStore.isBonusFlaskPermanentlyUnlocked)
    }

    func testPermanentBonusUnlockCarriesIntoNextLevel() async {
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            featureFlags: .allEnabled,
            timing: .immediate
        )

        viewModel.unlockBonusFlaskPermanently()
        await waitForScheduledMainQueueWork()
        viewModel.advanceToNextLevel()

        XCTAssertTrue(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isBonus == true)
        XCTAssertTrue(viewModel.gameManager.flasks.last?.isPlayable == true)
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

    func testValidMovePersistsAndRestoresActiveRoundSnapshot() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red, red]),
                    Flask(colors: [red])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 0,
            timing: .immediate
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(progressStore.activeRoundSnapshot?.moves, 1)

        let restoredViewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertEqual(restoredViewModel.moves, 1)
        XCTAssertEqual(restoredViewModel.gameManager.flasks.map(\.colors), viewModel.gameManager.flasks.map(\.colors))
        XCTAssertTrue(restoredViewModel.canUndo)
        XCTAssertTrue(restoredViewModel.hasActiveRoundInProgress)
    }

    func testBeginningOrderPersistsActiveRoundBeforeFirstMove() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 0,
            timing: .immediate
        )

        viewModel.beginCurrentOrder()

        XCTAssertEqual(progressStore.activeRoundSnapshot?.levelIndex, 0)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.moves, 0)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.flasks, viewModel.gameManager.flasks)
        XCTAssertTrue(viewModel.hasActiveRoundInProgress)
    }

    func testUsedFreeHintRemainsConsumedAfterRestoringRound() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 5
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 0,
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(progressStore.activeRoundSnapshot?.hintsUsedThisLevel, 1)

        let restoredViewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertEqual(restoredViewModel.hintsUsedThisLevel, 1)
        XCTAssertEqual(restoredViewModel.hintBadgeText, "\(HomeViewModel.extraHintHerbsCost)")
    }

    func testLegacyActiveRoundSnapshotDefaultsHintUsageToZero() throws {
        let snapshot = ActiveRoundSnapshot(
            levelIndex: 0,
            flasks: [Flask(colors: [red]), Flask()],
            moves: 0,
            history: []
        )
        let encodedData = try JSONEncoder().encode(snapshot)
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedData) as? [String: Any]
        )
        json.removeValue(forKey: "hintsUsedThisLevel")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decodedSnapshot = try JSONDecoder().decode(
            ActiveRoundSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(decodedSnapshot.hintsUsedThisLevel, 0)
        XCTAssertEqual(decodedSnapshot.rewardedHintCredits, 0)
    }

    func testValidPourEmitsFeedbackEvents() async {
        let feedbackProvider = SpyGameFeedbackProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red, red]),
                Flask(colors: [red])
            ],
            gameFeedbackProvider: feedbackProvider
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(feedbackProvider.events, [.flaskSelect, .validPour])
    }

    func testInvalidPourEmitsWarningFeedbackAndKeepsSourceSelected() {
        let feedbackProvider = SpyGameFeedbackProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [green])
            ],
            gameFeedbackProvider: feedbackProvider
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)

        XCTAssertEqual(feedbackProvider.events, [.flaskSelect, .invalidMove])
        XCTAssertEqual(viewModel.selectedFlaskIndex, 0)
    }

    func testOrderBannerStartsVisibleAndHidesAfterFirstFlaskTap() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ]
        )

        XCTAssertTrue(viewModel.isOrderBannerVisible)
        XCTAssertEqual(viewModel.orderTitle, "Order 1")

        viewModel.handleFlaskTap(at: 0)

        XCTAssertFalse(viewModel.isOrderBannerVisible)
    }

    func testOrderObjectiveSummaryUsesCustomerOrderAndTargetProgress() {
        let level = Level(
            id: 42,
            difficulty: .easy,
            filledFlasks: [
                Flask(colors: [yellow, yellow, red, blue]),
                Flask(colors: [yellow, green]),
                Flask(colors: [])
            ],
            availableEmptyFlaskCount: GameManager.startingEmptyFlaskCount,
            hasLockedBonusFlask: false,
            objective: .completeColor(yellow),
            customerOrder: CustomerOrder(
                customerName: "Mira",
                potionName: "Luck Potion",
                targetColor: yellow,
                rewardHerbs: 8,
                shortCopy: "Brew one bright luck potion."
            )
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(flasks: level.filledFlasks, level: level),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: .immediate
        )

        XCTAssertEqual(
            viewModel.orderObjectiveSummary,
            OrderObjectiveSummary(
                potionName: "Luck Potion",
                targetColor: yellow,
                progress: 2,
                requiredSections: Flask.maxCapacity,
                shortCopy: "Brew one bright luck potion."
            )
        )
        XCTAssertEqual(viewModel.orderSubtitle, "Brew one bright luck potion.")
    }

    func testOrderObjectiveSummaryIsNilForClassicLevels() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ]
        )

        XCTAssertNil(viewModel.orderObjectiveSummary)
    }

    func testTutorialPromptStartsVisibleAndHighlightsSuggestedMove() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ]
        )

        XCTAssertTrue(viewModel.isTutorialPromptVisible)
        XCTAssertEqual(viewModel.tutorialTitle, "Pour a potion")
        XCTAssertEqual(viewModel.tutorialMove, HintMove(sourceIndex: 0, targetIndex: 1))
    }

    func testTutorialPromptHidesAfterFirstInteraction() {
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ]
        )

        viewModel.handleFlaskTap(at: 0)

        XCTAssertFalse(viewModel.isTutorialPromptVisible)
    }

    func testTutorialCompletionPersistsOnFifthOrderInteraction() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 4,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 4,
            timing: .immediate
        )

        XCTAssertTrue(viewModel.isTutorialPromptVisible)

        viewModel.handleFlaskTap(at: 0)

        XCTAssertFalse(viewModel.isTutorialPromptVisible)
        XCTAssertTrue(progressStore.hasCompletedOnboarding)
    }

    func testTutorialPromptDoesNotShowWhenOnboardingIsCompleted() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            hasCompletedOnboarding: true
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertFalse(viewModel.isTutorialPromptVisible)
    }

    func testOrderBannerResetsWhenAdvancingToNextLevel() {
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: .immediate
        )

        viewModel.handleFlaskTap(at: 0)
        XCTAssertFalse(viewModel.isOrderBannerVisible)

        viewModel.advanceToNextLevel()

        XCTAssertTrue(viewModel.isOrderBannerVisible)
        XCTAssertEqual(viewModel.orderTitle, "Order 1")
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
        XCTAssertEqual(viewModel.victoryMessage, "Order Complete! Potion Perfect!")
        XCTAssertEqual(viewModel.lastCompletedMoveCount, 1)
    }

    func testVictoryMessageUsesCustomerOrderPotionName() async {
        let level = Level(
            id: 42,
            difficulty: .easy,
            filledFlasks: [
                Flask(colors: [yellow]),
                Flask(colors: [yellow, yellow, yellow]),
                Flask(colors: [red, red, red, red])
            ],
            availableEmptyFlaskCount: 0,
            hasLockedBonusFlask: false,
            objective: .completeColor(yellow),
            customerOrder: CustomerOrder(
                customerName: "Mira",
                potionName: "Luck Potion",
                targetColor: yellow,
                rewardHerbs: 8,
                shortCopy: "Brew one bright luck potion."
            )
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(flasks: level.filledFlasks, level: level),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            ),
            victoryMessageProvider: { "Fantastic!" }
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.victoryMessage, "Luck Potion brewed!")
        XCTAssertEqual(viewModel.lastCompletedMoveCount, 1)
    }

    func testVictoryAwardsAndPersistsHerbs() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 5,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 12
        )
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [red, red, red])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 5,
            gameAnalyticsProvider: analyticsProvider,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            ),
            victoryMessageProvider: { "Order Brewed!" }
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.lastHerbsReward, HomeViewModel.herbsRewardPerCompletedOrder)
        XCTAssertEqual(viewModel.herbsBalance, 12 + HomeViewModel.herbsRewardPerCompletedOrder)
        XCTAssertEqual(progressStore.herbsBalance, viewModel.herbsBalance)
        XCTAssertEqual(progressStore.currentLevelIndex, 6)
        XCTAssertEqual(analyticsProvider.events, [
            .levelCompleted(
                levelNumber: 6,
                moves: 1,
                herbsReward: HomeViewModel.herbsRewardPerCompletedOrder
            )
        ])
    }

    func testVictoryClearsActiveRoundSnapshot() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 5,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [red, red, red])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 5,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertNil(progressStore.activeRoundSnapshot)
    }

    func testRelaunchDuringCelebrationStartsNextLevelWithoutRepeatingReward() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 5,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 12
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [red, red, red])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 5,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        let rewardedBalance = 12 + HomeViewModel.herbsRewardPerCompletedOrder
        XCTAssertEqual(viewModel.completionPhase, .resolvingWin)
        XCTAssertEqual(progressStore.currentLevelIndex, 6)
        XCTAssertEqual(progressStore.herbsBalance, rewardedBalance)

        let relaunchedViewModel = HomeViewModel(
            levelRepository: HandcraftedLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertEqual(relaunchedViewModel.currentLevelIndex, 6)
        XCTAssertEqual(relaunchedViewModel.currentLevelNumber, 7)
        XCTAssertEqual(relaunchedViewModel.herbsBalance, rewardedBalance)
        XCTAssertEqual(relaunchedViewModel.completionPhase, .playing)
        XCTAssertFalse(relaunchedViewModel.hasActiveRoundInProgress)
    }

    func testTrainingRoundsDoNotAwardHerbs() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 3,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 12
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [red, red, red])
                ]
            ),
            progressStore: progressStore,
            currentLevelIndex: 3,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0,
                completionDuration: 10,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        XCTAssertNil(viewModel.lastHerbsReward)
        XCTAssertEqual(viewModel.herbsBalance, 12)
        XCTAssertEqual(progressStore.herbsBalance, 12)
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
        await waitForCompletionPhase(.celebrating, in: viewModel)

        XCTAssertEqual(viewModel.completionPhase, .celebrating)
    }

    func testUndoRestoresPreviousFlasksAfterValidMove() async {
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [blue]),
                Flask(colors: [])
            ],
            gameAnalyticsProvider: analyticsProvider
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()
        viewModel.undo()

        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertEqual(analyticsProvider.events, [.undoUsed(levelNumber: 1)])
    }

    func testInvalidMoveDoesNotEnterUndoHistoryAndKeepsSourceSelected() {
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
        XCTAssertEqual(viewModel.invalidFlaskIndices, [0, 1])
        XCTAssertEqual(viewModel.selectedFlaskIndex, 0)
    }

    func testHintHighlightsFirstValidMoveWithoutPouring() {
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = makeViewModel(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [])
            ],
            gameAnalyticsProvider: analyticsProvider
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.showHint()

        XCTAssertEqual(viewModel.hintMove, HintMove(sourceIndex: 0, targetIndex: 1))
        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertTrue(analyticsProvider.events.isEmpty)
    }

    func testFirstHintIsFreeAndSecondHintCostsHerbs() async throws {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 5
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            timing: .immediate
        )

        XCTAssertEqual(viewModel.hintBadgeText, "1")

        viewModel.showHint()

        XCTAssertEqual(viewModel.hintMove, HintMove(sourceIndex: 0, targetIndex: 2))
        XCTAssertEqual(viewModel.herbsBalance, 5)
        XCTAssertEqual(progressStore.herbsBalance, 5)
        XCTAssertEqual(viewModel.hintBadgeText, "1")

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()
        XCTAssertEqual(viewModel.hintBadgeText, "\(HomeViewModel.extraHintHerbsCost)")

        viewModel.showHint()

        XCTAssertEqual(viewModel.herbsBalance, 5)
        XCTAssertEqual(progressStore.herbsBalance, 5)
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        viewModel.purchaseHintWithHerbs()
        let paidHint = try XCTUnwrap(viewModel.hintMove)
        viewModel.handleFlaskTap(at: paidHint.sourceIndex)
        viewModel.handleFlaskTap(at: paidHint.targetIndex)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.herbsBalance, 5 - HomeViewModel.extraHintHerbsCost)
        XCTAssertEqual(progressStore.herbsBalance, viewModel.herbsBalance)
    }

    func testPaidHintDoesNotSpendHerbsWhenPlayerChoosesDifferentMove() async throws {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 5
        )
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()

        viewModel.showHint()
        XCTAssertEqual(
            viewModel.hintPurchasePrompt?.hintMove,
            HintMove(sourceIndex: 1, targetIndex: 0)
        )
        viewModel.purchaseHintWithHerbs()
        viewModel.handleFlaskTap(at: 2)
        viewModel.handleFlaskTap(at: 0)
        await waitForScheduledMainQueueWork()

        XCTAssertNil(viewModel.hintMove)
        XCTAssertEqual(viewModel.herbsBalance, 5)
        XCTAssertEqual(progressStore.herbsBalance, 5)
        XCTAssertEqual(analyticsProvider.events, [
            .hintUsed(levelNumber: 1, payment: .free)
        ])
    }

    func testLevelFiveFirstHintCostsHerbsWhenHintMoveIsUsed() async throws {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 4,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 8,
            hasSeenHerbsTutorial: true
        )
        let viewModel = HomeViewModel(
            progressStore: progressStore,
            currentLevelIndex: 4,
            timing: .immediate
        )

        XCTAssertEqual(viewModel.currentLevelNumber, 5)
        XCTAssertEqual(viewModel.tutorialTitle, "Use herbs")
        XCTAssertEqual(viewModel.hintBadgeText, "\(HomeViewModel.extraHintHerbsCost)")

        viewModel.showHint()

        XCTAssertEqual(viewModel.herbsBalance, 8)
        XCTAssertEqual(progressStore.herbsBalance, 8)
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        viewModel.purchaseHintWithHerbs()
        XCTAssertTrue(viewModel.canInteractWithBoard)
        let hint = try XCTUnwrap(viewModel.hintMove)
        viewModel.handleFlaskTap(at: hint.sourceIndex)
        viewModel.handleFlaskTap(at: hint.targetIndex)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.herbsBalance, 8 - HomeViewModel.extraHintHerbsCost)
        XCTAssertEqual(progressStore.herbsBalance, viewModel.herbsBalance)
    }

    func testLevelFivePresentsHerbsTutorialAndBlocksHintUntilClaimed() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 4,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 0
        )
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            progressStore: progressStore,
            currentLevelIndex: 4,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        XCTAssertNil(viewModel.herbsTutorialPrompt)
        viewModel.beginCurrentOrder()
        XCTAssertEqual(viewModel.herbsTutorialPrompt?.herbsAmount, HomeViewModel.extraHintHerbsCost)
        XCTAssertTrue(progressStore.hasSeenHerbsTutorial)
        XCTAssertEqual(viewModel.herbsBalance, HomeViewModel.extraHintHerbsCost)
        XCTAssertEqual(progressStore.herbsBalance, HomeViewModel.extraHintHerbsCost)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        XCTAssertFalse(viewModel.canShowHint)
        XCTAssertNil(viewModel.tutorialMove)
        XCTAssertNil(viewModel.hintMove)
        XCTAssertFalse(viewModel.shouldPromptHintUse)
        XCTAssertEqual(analyticsProvider.events, [
            .levelStarted(levelNumber: 5)
        ])

        viewModel.claimHerbsTutorialReward()

        XCTAssertNil(viewModel.herbsTutorialPrompt)
        XCTAssertEqual(viewModel.herbsBalance, HomeViewModel.extraHintHerbsCost)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        XCTAssertTrue(viewModel.canShowHint)
        XCTAssertNil(viewModel.tutorialMove)
        XCTAssertNil(viewModel.hintMove)
        XCTAssertTrue(viewModel.shouldPromptHintUse)

        viewModel.showHint()

        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        XCTAssertNil(viewModel.hintMove)
        XCTAssertFalse(viewModel.canInteractWithBoard)
        viewModel.purchaseHintWithHerbs()
        XCTAssertNotNil(viewModel.hintMove)
        XCTAssertEqual(viewModel.herbsBalance, HomeViewModel.extraHintHerbsCost)
        XCTAssertTrue(viewModel.canInteractWithBoard)
        XCTAssertFalse(viewModel.shouldPromptHintUse)
        XCTAssertEqual(analyticsProvider.events, [
            .levelStarted(levelNumber: 5)
        ])
    }

    func testMenuRewardUsesLeafOnlyUntilFourthLevelIsCompleted() {
        let tutorialViewModel = HomeViewModel(
            progressStore: SpyProgressStore(
                currentLevelIndex: 3,
                isBonusFlaskPermanentlyUnlocked: false
            ),
            currentLevelIndex: 3,
            timing: .immediate
        )
        let rewardViewModel = HomeViewModel(
            progressStore: SpyProgressStore(
                currentLevelIndex: 4,
                isBonusFlaskPermanentlyUnlocked: false
            ),
            currentLevelIndex: 4,
            timing: .immediate
        )

        XCTAssertEqual(tutorialViewModel.menuRewardText, "")
        XCTAssertEqual(rewardViewModel.menuRewardText, "+\(HomeViewModel.herbsRewardPerCompletedOrder)")
    }

    @MainActor
    func testAdvancingToLevelFiveDoesNotPresentHerbsTutorialBeforeOrderStarts() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 3,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 0
        )
        let viewModel = HomeViewModel(
            progressStore: progressStore,
            currentLevelIndex: 3,
            timing: .immediate
        )

        viewModel.advanceToNextLevel()

        XCTAssertEqual(viewModel.currentLevelIndex, 4)
        XCTAssertEqual(viewModel.currentLevelNumber, 5)
        XCTAssertNil(viewModel.herbsTutorialPrompt)

        viewModel.beginCurrentOrder()

        XCTAssertEqual(viewModel.herbsTutorialPrompt?.herbsAmount, HomeViewModel.extraHintHerbsCost)
    }

    func testSecondLevelStartsWithMiddleFlaskSelectedAndMarkersVisible() {
        let viewModel = HomeViewModel(
            levelRepository: HandcraftedLevelRepository(),
            progressStore: SpyProgressStore(
                currentLevelIndex: 1,
                isBonusFlaskPermanentlyUnlocked: false
            ),
            currentLevelIndex: 1,
            timing: .immediate
        )

        XCTAssertEqual(viewModel.selectedFlaskIndex, 1)
        XCTAssertEqual(viewModel.tutorialMarkers, [
            TutorialMarker(flaskIndex: 0, kind: .correctTarget),
            TutorialMarker(flaskIndex: 2, kind: .blockedTarget)
        ])
        XCTAssertTrue(viewModel.centersSparseTutorialRows)
    }

    func testRepeatedTapOnSameHintDoesNotSpendHerbsAgain() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 5
        )
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.showHint()

        XCTAssertEqual(viewModel.herbsBalance, 5)
        XCTAssertEqual(progressStore.herbsBalance, 5)
    }

    func testHintFallsBackToRewardedAdWhenHerbsRunOut() async {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 0
        )
        let rewardedAdProvider = SpyRewardedAdProvider(result: true)
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        XCTAssertTrue(viewModel.canShowHint)
        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()

        XCTAssertTrue(viewModel.canShowHint)
        XCTAssertEqual(viewModel.hintBadgeText, "Ad")
        viewModel.showHint()
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        XCTAssertFalse(viewModel.isRewardedHintInProgress)
        viewModel.purchaseHintWithRewardedAd()
        XCTAssertTrue(viewModel.isRewardedHintInProgress)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.hintMove, HintMove(sourceIndex: 1, targetIndex: 0))
        XCTAssertFalse(viewModel.isRewardedHintInProgress)
        XCTAssertEqual(viewModel.herbsBalance, 0)
        XCTAssertEqual(progressStore.herbsBalance, 0)
        XCTAssertEqual(viewModel.rewardedHintCredits, 1)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.rewardedHintCredits, 1)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)
        XCTAssertEqual(rewardedAdProvider.placements, [.extraHint])
        XCTAssertEqual(analyticsProvider.events, [
            .hintUsed(levelNumber: 1, payment: .free),
            .rewardedAdStarted(levelNumber: 1, placement: .extraHint),
            .rewardedAdCompleted(levelNumber: 1, placement: .extraHint, success: true)
        ])
    }

    func testEarnedRewardedHintSurvivesAnotherMoveAndRoundRestore() async throws {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 0
        )
        let rewardedAdProvider = SpyRewardedAdProvider(result: true)
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: progressStore,
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()

        viewModel.showHint()
        viewModel.purchaseHintWithRewardedAd()
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(viewModel.rewardedHintCredits, 1)
        XCTAssertEqual(viewModel.hintMove, HintMove(sourceIndex: 1, targetIndex: 0))

        viewModel.handleFlaskTap(at: 2)
        viewModel.handleFlaskTap(at: 0)
        await waitForScheduledMainQueueWork()

        XCTAssertNil(viewModel.hintMove)
        XCTAssertEqual(viewModel.rewardedHintCredits, 1)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.rewardedHintCredits, 1)

        let restoredViewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        XCTAssertEqual(restoredViewModel.rewardedHintCredits, 1)
        XCTAssertEqual(restoredViewModel.hintBadgeText, "Ready")
        restoredViewModel.showHint()
        let earnedHint = try XCTUnwrap(restoredViewModel.hintMove)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)

        restoredViewModel.handleFlaskTap(at: earnedHint.sourceIndex)
        restoredViewModel.handleFlaskTap(at: earnedHint.targetIndex)
        await waitForScheduledMainQueueWork()

        XCTAssertEqual(restoredViewModel.rewardedHintCredits, 0)
        XCTAssertEqual(restoredViewModel.hintsUsedThisLevel, 2)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.rewardedHintCredits, 0)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)
        XCTAssertEqual(analyticsProvider.events, [
            .hintUsed(levelNumber: 1, payment: .free),
            .rewardedAdStarted(levelNumber: 1, placement: .extraHint),
            .rewardedAdCompleted(levelNumber: 1, placement: .extraHint, success: true),
            .hintUsed(levelNumber: 1, payment: .rewardedAd)
        ])
    }

    func testHintIsUnavailableWhenHerbsRunOutAndAdsAreDisabled() async {
        let rewardedAdProvider = SpyRewardedAdProvider(result: true)
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: SpyProgressStore(
                currentLevelIndex: 5,
                isBonusFlaskPermanentlyUnlocked: false,
                herbsBalance: 0
            ),
            rewardedAdProvider: rewardedAdProvider,
            featureFlags: GameFeatureFlags(
                rewardedAdsEnabled: false,
                permanentBonusFlaskPurchaseEnabled: false
            ),
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()

        XCTAssertFalse(viewModel.canShowHint)
        XCTAssertEqual(viewModel.hintBadgeText, "")
        viewModel.showHint()
        XCTAssertNil(viewModel.hintMove)
        XCTAssertNil(viewModel.hintPurchasePrompt)
        XCTAssertFalse(viewModel.isRewardedHintInProgress)
        XCTAssertEqual(rewardedAdProvider.showCount, 0)
    }

    func testRewardedAdHintDoesNotRevealHintWhenRewardFails() async {
        let rewardedAdProvider = SpyRewardedAdProvider(result: false)
        let analyticsProvider = SpyGameAnalyticsProvider()
        let viewModel = HomeViewModel(
            gameManager: GameManager(
                flasks: [
                    Flask(colors: [red]),
                    Flask(colors: [green]),
                    Flask()
                ]
            ),
            progressStore: SpyProgressStore(
                currentLevelIndex: 0,
                isBonusFlaskPermanentlyUnlocked: false,
                herbsBalance: 0
            ),
            rewardedAdProvider: rewardedAdProvider,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )

        viewModel.showHint()
        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 2)
        await waitForScheduledMainQueueWork()
        viewModel.showHint()
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        viewModel.purchaseHintWithRewardedAd()
        await waitForScheduledMainQueueWork()

        XCTAssertNil(viewModel.hintMove)
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        XCTAssertFalse(viewModel.isRewardedHintInProgress)
        XCTAssertEqual(viewModel.hintsUsedThisLevel, 1)
        XCTAssertEqual(rewardedAdProvider.showCount, 1)
        XCTAssertEqual(rewardedAdProvider.placements, [.extraHint])
        XCTAssertEqual(analyticsProvider.events, [
            .hintUsed(levelNumber: 1, payment: .free),
            .rewardedAdStarted(levelNumber: 1, placement: .extraHint),
            .rewardedAdCompleted(levelNumber: 1, placement: .extraHint, success: false)
        ])
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

    func testResetAfterFirstMoveRequiresConfirmation() async {
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: .immediate
        )

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()
        let movedFlasks = viewModel.gameManager.flasks

        viewModel.requestReset()

        XCTAssertNotNil(viewModel.resetConfirmationPrompt)
        XCTAssertEqual(viewModel.gameManager.flasks, movedFlasks)

        viewModel.cancelReset()

        XCTAssertNil(viewModel.resetConfirmationPrompt)
        XCTAssertEqual(viewModel.gameManager.flasks, movedFlasks)
    }

    func testResetOnLaterLevelRequiresConfirmationBeforeFirstMove() {
        let viewModel = HomeViewModel(
            levelRepository: HandcraftedLevelRepository(),
            userDefaults: testUserDefaults,
            currentLevelIndex: Level.lockedBonusIntroductionLevelID - 1,
            isBonusFlaskPermanentlyUnlocked: false,
            timing: .immediate
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.requestReset()

        XCTAssertNotNil(viewModel.resetConfirmationPrompt)
        XCTAssertEqual(viewModel.gameManager.flasks, initialFlasks)
    }

    func testConfirmResetRestartsCurrentLevel() async {
        let analyticsProvider = SpyGameAnalyticsProvider()
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            gameAnalyticsProvider: analyticsProvider,
            timing: .immediate
        )
        let initialFlasks = viewModel.gameManager.flasks

        viewModel.handleFlaskTap(at: 0)
        viewModel.handleFlaskTap(at: 1)
        await waitForScheduledMainQueueWork()

        viewModel.requestReset()
        viewModel.confirmReset()

        XCTAssertNil(viewModel.resetConfirmationPrompt)
        XCTAssertEqual(viewModel.gameManager.flasks.map(\.colors), initialFlasks.map(\.colors))
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertFalse(viewModel.canUndo)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.levelIndex, 0)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.moves, 0)
        XCTAssertEqual(progressStore.activeRoundSnapshot?.flasks, viewModel.gameManager.flasks)
        XCTAssertEqual(analyticsProvider.events, [
            .resetRequested(levelNumber: 1),
            .resetConfirmed(levelNumber: 1)
        ])
    }

    func testResetProgressForTestingClearsPersistentProgress() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 5,
            isBonusFlaskPermanentlyUnlocked: true,
            herbsBalance: 42,
            hasCompletedOnboarding: true
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        viewModel.resetProgressForTesting()

        XCTAssertEqual(viewModel.currentLevelIndex, 0)
        XCTAssertFalse(viewModel.isBonusFlaskPermanentlyUnlocked)
        XCTAssertEqual(viewModel.herbsBalance, 0)
        XCTAssertTrue(viewModel.isTutorialPromptVisible)
        XCTAssertEqual(progressStore.currentLevelIndex, 0)
        XCTAssertFalse(progressStore.isBonusFlaskPermanentlyUnlocked)
        XCTAssertEqual(progressStore.herbsBalance, 0)
        XCTAssertFalse(progressStore.hasSeenIntro)
        XCTAssertFalse(progressStore.hasCompletedOnboarding)
        XCTAssertNil(progressStore.activeRoundSnapshot)
    }

    func testJumpToLevelForTestingLoadsRequestedLevelNumber() {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 0,
            hasCompletedOnboarding: true
        )
        let viewModel = HomeViewModel(
            levelRepository: HandcraftedLevelRepository(),
            progressStore: progressStore,
            timing: .immediate
        )

        viewModel.jumpToLevelForTesting(61)

        XCTAssertEqual(viewModel.currentLevelIndex, 60)
        XCTAssertEqual(viewModel.currentLevelNumber, 61)
        XCTAssertEqual(progressStore.currentLevelIndex, 60)
        XCTAssertEqual(viewModel.gameManager.level?.id, 61)
        XCTAssertTrue(viewModel.gameManager.level?.revealsOnlyTopColor == true)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertFalse(viewModel.canUndo)
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

    func testCancellingHintedPourBeforeCompletionDoesNotSpendHerbs() async throws {
        let progressStore = SpyProgressStore(
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            herbsBalance: 5
        )
        progressStore.activeRoundSnapshot = ActiveRoundSnapshot(
            levelIndex: 0,
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [green]),
                Flask()
            ],
            moves: 0,
            history: [],
            hintsUsedThisLevel: 1
        )
        let viewModel = HomeViewModel(
            levelRepository: SingleLevelRepository(),
            progressStore: progressStore,
            timing: HomeViewModelTiming(
                pourAnimationDuration: 0.25,
                completionDuration: 0,
                invalidFeedbackDuration: 0
            )
        )

        viewModel.showHint()
        XCTAssertNotNil(viewModel.hintPurchasePrompt)
        viewModel.purchaseHintWithHerbs()
        let hint = try XCTUnwrap(viewModel.hintMove)
        viewModel.handleFlaskTap(at: hint.sourceIndex)
        viewModel.handleFlaskTap(at: hint.targetIndex)

        XCTAssertNotNil(viewModel.pourAnimation)
        XCTAssertEqual(viewModel.herbsBalance, 5)
        viewModel.startNewGame()
        await waitForScheduledMainQueueWork(nanoseconds: 350_000_000)

        XCTAssertEqual(viewModel.herbsBalance, 5)
        XCTAssertEqual(progressStore.herbsBalance, 5)
        XCTAssertEqual(viewModel.moves, 0)
        XCTAssertEqual(viewModel.hintsUsedThisLevel, 0)
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
        rewardedAdProvider: any RewardedAdProviding = StubRewardedAdProvider(),
        bonusFlaskPurchaseProvider: any BonusFlaskPurchaseProviding = StubBonusFlaskPurchaseProvider(),
        gameFeedbackProvider: (any GameFeedbackProviding)? = nil,
        gameAnalyticsProvider: (any GameAnalyticsProviding)? = nil,
        featureFlags: GameFeatureFlags = .alpha,
        timing: HomeViewModelTiming = .immediate,
        victoryMessageProvider: @escaping () -> String = { "Fantastic!" }
    ) -> HomeViewModel {
        HomeViewModel(
            gameManager: GameManager(flasks: flasks),
            userDefaults: userDefaults ?? testUserDefaults,
            currentLevelIndex: 0,
            isBonusFlaskPermanentlyUnlocked: false,
            rewardedAdProvider: rewardedAdProvider,
            bonusFlaskPurchaseProvider: bonusFlaskPurchaseProvider,
            gameFeedbackProvider: gameFeedbackProvider,
            gameAnalyticsProvider: gameAnalyticsProvider,
            featureFlags: featureFlags,
            timing: timing,
            victoryMessageProvider: victoryMessageProvider
        )
    }

    private func waitForScheduledMainQueueWork(nanoseconds: UInt64 = 50_000_000) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private func waitForCompletionPhase(
        _ phase: LevelCompletionPhase,
        in viewModel: HomeViewModel,
        timeoutNanoseconds: UInt64 = 700_000_000
    ) async {
        let stepNanoseconds: UInt64 = 25_000_000
        var elapsedNanoseconds: UInt64 = 0

        while viewModel.completionPhase != phase, elapsedNanoseconds < timeoutNanoseconds {
            await waitForScheduledMainQueueWork(nanoseconds: stepNanoseconds)
            elapsedNanoseconds += stepNanoseconds
        }
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
    var activeRoundSnapshot: ActiveRoundSnapshot?
    var isBonusFlaskPermanentlyUnlocked: Bool
    var herbsBalance: Int
    var hasSeenIntro: Bool
    var hasCompletedOnboarding: Bool
    var hasSeenHerbsTutorial: Bool
    var isSoundEnabled: Bool
    var isHapticsEnabled: Bool

    init(
        currentLevelIndex: Int,
        isBonusFlaskPermanentlyUnlocked: Bool,
        herbsBalance: Int = 0,
        hasSeenIntro: Bool = false,
        hasCompletedOnboarding: Bool = false,
        hasSeenHerbsTutorial: Bool = false,
        isSoundEnabled: Bool = true,
        isHapticsEnabled: Bool = true
    ) {
        self.currentLevelIndex = currentLevelIndex
        self.activeRoundSnapshot = nil
        self.isBonusFlaskPermanentlyUnlocked = isBonusFlaskPermanentlyUnlocked
        self.herbsBalance = herbsBalance
        self.hasSeenIntro = hasSeenIntro
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasSeenHerbsTutorial = hasSeenHerbsTutorial
        self.isSoundEnabled = isSoundEnabled
        self.isHapticsEnabled = isHapticsEnabled
    }
}

@MainActor
private final class SpyGameFeedbackProvider: GameFeedbackProviding {
    private(set) var events: [GameFeedbackEvent] = []

    func play(_ event: GameFeedbackEvent) {
        events.append(event)
    }
}

@MainActor
private final class SpyGameAnalyticsProvider: GameAnalyticsProviding {
    private(set) var events: [GameAnalyticsEvent] = []

    func track(_ event: GameAnalyticsEvent) {
        events.append(event)
    }
}

private final class SpyRewardedAdProvider: RewardedAdProviding {
    let result: Bool
    private(set) var showCount = 0
    private(set) var placements: [RewardedAdPlacement] = []

    init(result: Bool) {
        self.result = result
    }

    func showRewardedAd(for placement: RewardedAdPlacement) async -> Bool {
        showCount += 1
        placements.append(placement)
        return result
    }
}

private final class SpyBonusFlaskPurchaseProvider: BonusFlaskPurchaseProviding {
    let result: PurchaseResult
    private(set) var products: [PurchaseProduct] = []

    init(result: PurchaseResult) {
        self.result = result
    }

    func purchase(_ product: PurchaseProduct) async -> PurchaseResult {
        products.append(product)
        return result
    }
}
