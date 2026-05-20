import CoreGraphics
import SwiftUI

struct HomeLayout {
    let columns: Int

    init(columns: Int = 4) {
        self.columns = columns
    }

    func scale(in size: CGSize) -> CGFloat {
        guard size.width > GameMetric.baseBoardWidth || size.height > GameMetric.baseBoardHeight else {
            return 1
        }

        return min(
            GameMetric.maxLayoutScale,
            min(size.width / GameMetric.baseBoardWidth, size.height / GameMetric.baseBoardHeight)
        )
    }

    func flaskCenter(for index: Int, in size: CGSize, scale: CGFloat) -> CGPoint {
        let column = index % columns
        let row = index / columns
        let boardWidth = min(size.width - 36 * scale, GameMetric.baseBoardWidth * scale)
        let boardOriginX = (size.width - boardWidth) / 2
        let verticalCenter = size.height * 0.48
        let cellWidth = boardWidth / CGFloat(columns)
        let rowSpacing: CGFloat = min(230 * scale, size.height * 0.26)

        return CGPoint(
            x: boardOriginX + cellWidth * (CGFloat(column) + 0.5),
            y: verticalCenter + (CGFloat(row) - 0.5) * rowSpacing
        )
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
        size.height - safeAreaInsets.bottom - GameMetric.bottomControlInset * scale - GameMetric.iconButtonSize * scale / 2
    }

    func testingButtonCenterY(in size: CGSize, safeAreaInsets: EdgeInsets, scale: CGFloat) -> CGFloat {
        size.height - safeAreaInsets.bottom - 18 * scale
    }
}
