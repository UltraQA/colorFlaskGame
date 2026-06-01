import CoreGraphics
import SwiftUI
import XCTest
@testable import ColorFlaskGame

final class HomeLayoutTests: XCTestCase {
    private let layout = HomeLayout()

    func testBoardLayoutFitsCompactPortraitPhone() {
        assertBoardFits(
            size: CGSize(width: 320, height: 568),
            safeAreaInsets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        )
    }

    func testBoardLayoutFitsStandardPortraitPhone() {
        assertBoardFits(
            size: CGSize(width: 393, height: 852),
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        )
    }

    func testBoardLayoutScalesOnPortraitIPadWithoutExceedingMaximumScale() {
        let size = CGSize(width: 834, height: 1194)
        let scale = layout.scale(in: size)

        XCTAssertEqual(scale, GameMetric.maxLayoutScale, accuracy: 0.001)
        assertBoardFits(
            size: size,
            safeAreaInsets: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0)
        )
    }

    func testBottomControlsSitNearPhysicalBottom() {
        let size = CGSize(width: 393, height: 852)
        let safeAreaInsets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        let scale = layout.scale(in: size)
        let centerY = layout.bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets, scale: scale)
        let bottomEdge = centerY + GameMetric.bottomControlDockHeight * scale / 2

        XCTAssertLessThanOrEqual(bottomEdge, size.height)
        XCTAssertGreaterThan(bottomEdge, size.height - safeAreaInsets.bottom)
    }

    func testBoardKeepsClearanceFromBottomControlsOnStandardPhone() {
        let size = CGSize(width: 393, height: 852)
        let safeAreaInsets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        let scale = layout.scale(in: size)
        let bottomControlCenterY = layout.bottomControlCenterY(in: size, safeAreaInsets: safeAreaInsets, scale: scale)
        let dockTopEdge = bottomControlCenterY - GameMetric.bottomControlDockHeight * scale / 2
        let bottomRowCenter = layout.flaskCenter(for: 4, in: size, scale: scale)
        let bottomRowEdge = bottomRowCenter.y + GameMetric.flaskHitHeight * scale / 2

        XCTAssertLessThanOrEqual(bottomRowEdge + 24 * scale, dockTopEdge)
    }

    func testSparseTutorialFlasksSitInGameAreaCenter() {
        let size = CGSize(width: 393, height: 852)
        let scale = layout.scale(in: size)
        let firstCenter = layout.flaskCenter(for: 0, totalCount: 2, centersSparseRows: true, in: size, scale: scale)
        let secondCenter = layout.flaskCenter(for: 1, totalCount: 2, centersSparseRows: true, in: size, scale: scale)

        XCTAssertEqual(firstCenter.y, size.height * GameMetric.sparseTutorialBoardVerticalCenterRatio, accuracy: 0.001)
        XCTAssertEqual(secondCenter.y, firstCenter.y, accuracy: 0.001)
        XCTAssertLessThan(firstCenter.x, size.width / 2)
        XCTAssertGreaterThan(secondCenter.x, size.width / 2)
    }

    private func assertBoardFits(size: CGSize, safeAreaInsets: EdgeInsets) {
        let scale = layout.scale(in: size)
        let flaskHalfWidth = GameMetric.flaskHitWidth * scale / 2
        let flaskHalfHeight = GameMetric.flaskHitHeight * scale / 2

        for index in 0..<8 {
            let center = layout.flaskCenter(for: index, in: size, scale: scale)
            XCTAssertGreaterThanOrEqual(center.x - flaskHalfWidth, 0, "Flask \(index) clips left")
            XCTAssertLessThanOrEqual(center.x + flaskHalfWidth, size.width, "Flask \(index) clips right")
            XCTAssertGreaterThanOrEqual(center.y - flaskHalfHeight, safeAreaInsets.top, "Flask \(index) clips top")
            XCTAssertLessThanOrEqual(center.y + flaskHalfHeight, size.height - safeAreaInsets.bottom, "Flask \(index) clips bottom")
        }
    }
}
