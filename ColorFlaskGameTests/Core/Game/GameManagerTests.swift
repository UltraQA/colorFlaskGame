import SwiftUI
import XCTest
@testable import ColorFlaskGame

final class GameManagerTests: XCTestCase {
    private let red = Color.red
    private let green = Color.green
    private let blue = Color.blue
    private let yellow = Color.yellow

    func testGeneratedLevelStartsWithTwoAvailableEmptyFlasksAndLockedBonusFlask() {
        let manager = GameManager.makeInitialLevel(filledFlaskCount: 5)

        XCTAssertEqual(manager.flasks.count, GameManager.defaultFlaskCount)
        XCTAssertEqual(manager.flasks.filter(\.isEmpty).count, 3)
        XCTAssertEqual(manager.flasks.filter { $0.isEmpty && $0.isPlayable }.count, 2)

        let bonusFlasks = manager.flasks.filter(\.isBonus)
        XCTAssertEqual(bonusFlasks.count, 1)
        XCTAssertFalse(bonusFlasks[0].isPlayable)
    }

    func testHandcraftedLevelsPassValidation() {
        let repository = HandcraftedLevelRepository()

        XCTAssertFalse(repository.levels.isEmpty)

        for level in repository.levels {
            XCTAssertTrue(
                level.isValid,
                "Level \(level.id) has validation issues: \(level.validationIssues.map(\.message))"
            )
        }
    }

    func testInvalidLevelReportsValidationIssues() {
        let level = Level(
            id: 99,
            difficulty: .easy,
            filledFlasks: [
                Flask(colors: [red, red]),
                Flask(kind: .bonus, colors: [green, green, green, green])
            ],
            availableEmptyFlaskCount: 1,
            hasLockedBonusFlask: false
        )

        XCTAssertFalse(level.isValid)
        XCTAssertFalse(level.validationIssues.isEmpty)
    }

    func testPourIntoMatchingColorMovesOnlyContiguousTopRun() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [red, blue, blue]),
                Flask(colors: [blue])
            ]
        )

        let result = manager.pour(from: 0, to: 1)

        XCTAssertEqual(result, .success(2))
        XCTAssertEqual(manager.flasks[0].colors, [red])
        XCTAssertEqual(manager.flasks[1].colors, [blue, blue, blue])
    }

    func testPourIntoEmptyFlaskRespectsTargetCapacity() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [red, red, red, red]),
                Flask(colors: [])
            ]
        )

        let result = manager.pour(from: 0, to: 1)

        XCTAssertEqual(result, .success(4))
        XCTAssertTrue(manager.flasks[0].isEmpty)
        XCTAssertEqual(manager.flasks[1].colors, [red, red, red, red])
    }

    func testPourRejectsDifferentColorOnTargetTop() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [red]),
                Flask(colors: [green])
            ]
        )
        let previousFlasks = manager.flasks

        let result = manager.pour(from: 0, to: 1)

        XCTAssertEqual(result, .failure(.colorMismatch))
        XCTAssertEqual(manager.flasks, previousFlasks)
    }

    func testPourRejectsFullTargetFlask() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [yellow]),
                Flask(colors: [yellow, yellow, yellow, yellow])
            ]
        )

        let result = manager.pour(from: 0, to: 1)

        XCTAssertEqual(result, .failure(.targetIsFull))
        XCTAssertEqual(manager.flasks[0].colors, [yellow])
        XCTAssertEqual(manager.flasks[1].colors, [yellow, yellow, yellow, yellow])
    }

    func testLockedBonusFlaskCannotParticipateInPourUntilUnlocked() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [red]),
                Flask(kind: .bonus, colors: [], isUnlocked: false)
            ]
        )

        XCTAssertEqual(manager.pour(from: 0, to: 1), .failure(.flaskIsLocked))

        manager.unlockBonusFlaskForCurrentRound()

        XCTAssertEqual(manager.pour(from: 0, to: 1), .success(1))
        XCTAssertEqual(manager.flasks[1].colors, [red])
    }

    func testRoundCompletionIgnoresLockedBonusFlask() {
        let manager = GameManager(
            flasks: [
                Flask(colors: [red, red, red, red]),
                Flask(colors: [blue, blue, blue, blue]),
                Flask(kind: .bonus, colors: [], isUnlocked: false)
            ]
        )

        XCTAssertTrue(manager.isRoundCompleted)
    }
}
