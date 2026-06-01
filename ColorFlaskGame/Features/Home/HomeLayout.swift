import CoreGraphics
import SwiftUI

struct HomeLayout {
    let columns: Int

    init(columns: Int = 4) {
        self.columns = columns
    }

    func scale(in size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.height.isFinite, size.width > 1, size.height > 1 else {
            return 1
        }

        guard size.width > GameMetric.baseBoardWidth || size.height > GameMetric.baseBoardHeight else {
            return 1
        }

        return min(
            GameMetric.maxLayoutScale,
            min(size.width / GameMetric.baseBoardWidth, size.height / GameMetric.baseBoardHeight)
        )
    }

    func flaskCenter(for index: Int, totalCount: Int, centersSparseRows: Bool, in size: CGSize, scale: CGFloat) -> CGPoint {
        let columnsInRow = centersSparseRows ? columnsInRow(for: totalCount) : columns
        let column = index % columnsInRow
        let row = index / columnsInRow
        let rowCount = Int(ceil(Double(max(totalCount, 1)) / Double(max(columnsInRow, 1))))
        let boardWidth = max(
            GameMetric.flaskHitWidth * scale,
            min(size.width - 36 * scale, GameMetric.baseBoardWidth * scale)
        )
        let boardOriginX = (size.width - boardWidth) / 2
        let verticalCenterRatio = verticalCenterRatio(centersSparseRows: centersSparseRows, rowCount: rowCount)
        let verticalCenter = size.height * verticalCenterRatio
        let cellWidth = boardWidth / CGFloat(columnsInRow)
        let rowSpacing: CGFloat = min(210 * scale, size.height * GameMetric.boardRowSpacingRatio)
        let rowOffset = centersSparseRows
            ? CGFloat(row) * rowSpacing
            : (CGFloat(row) - CGFloat(rowCount - 1) / 2) * rowSpacing

        return CGPoint(
            x: boardOriginX + cellWidth * (CGFloat(column) + 0.5),
            y: verticalCenter + rowOffset
        )
    }

    func flaskCenter(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        flaskCenter(for: index, totalCount: columns * 2, centersSparseRows: false, in: size, scale: scale)
    }

    func pourStartPoint(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        let center = flaskCenter(for: index, in: size, scale: scale)
        return CGPoint(x: center.x, y: center.y - 108 * scale)
    }

    func pourEndPoint(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        let center = flaskCenter(for: index, in: size, scale: scale)
        return CGPoint(x: center.x, y: center.y - 92 * scale)
    }

    func bottomControlCenterY(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> CGFloat {
        let dockHeight = GameMetric.bottomControlDockHeight * scale
        let desiredCenterY = size.height - safeAreaInsets.bottom - GameMetric.bottomControlInset * scale - dockHeight / 2
        let lowestVisibleCenterY = size.height - dockHeight / 2 - 2 * scale

        return min(desiredCenterY, lowestVisibleCenterY)
    }

    private func columnsInRow(for totalCount: Int) -> Int {
        switch totalCount {
        case 0...2:
            return max(1, totalCount)
        case 3:
            return 3
        default:
            return columns
        }
    }

    private func verticalCenterRatio(centersSparseRows: Bool, rowCount: Int) -> CGFloat {
        if centersSparseRows {
            return GameMetric.sparseTutorialBoardVerticalCenterRatio
        }

        if rowCount >= 3 {
            return GameMetric.denseBoardVerticalCenterRatio
        }

        return GameMetric.boardVerticalCenterRatio
    }
}
