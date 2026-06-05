import SwiftUI

enum DSColor {
    static let background = Color(red: 0.96, green: 0.98, blue: 0.99)
    static let surface = Color.white
    static let brand = Color(red: 0.00, green: 0.48, blue: 0.86)
    static let accent = Color(red: 1.00, green: 0.50, blue: 0.20)
    static let success = Color(red: 0.12, green: 0.64, blue: 0.43)
    static let textPrimary = Color(red: 0.08, green: 0.11, blue: 0.15)
    static let textSecondary = Color(red: 0.38, green: 0.43, blue: 0.50)
    static let stroke = Color(red: 0.84, green: 0.88, blue: 0.92)
}

enum DSTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded, weight: .medium)
}

enum DSSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum DSCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
}

enum GameLayer {
    static let background: Double = 0
    static let board: Double = 10
    static let controls: Double = 20
    static let animation: Double = 30
    static let celebration: Double = 40
}

enum GameMetric {
    static let baseBoardWidth: CGFloat = 430
    static let baseBoardHeight: CGFloat = 932
    static let maxLayoutScale: CGFloat = 1.28
    static let flaskWidth: CGFloat = 78
    static let flaskHeight: CGFloat = 172
    static let flaskHitWidth: CGFloat = 104
    static let flaskHitHeight: CGFloat = 196
    static let liquidInset: CGFloat = 9
    static let liquidBottomInset: CGFloat = 9
    static let resetButtonWidth: CGFloat = 104
    static let resetButtonHeight: CGFloat = 72
    static let iconButtonSize: CGFloat = 68
    static let bottomControlDockWidth: CGFloat = 322
    static let bottomControlDockHeight: CGFloat = 92
    static let boardVerticalCenterRatio: CGFloat = 0.52
    static let denseBoardVerticalCenterRatio: CGFloat = 0.48
    static let sparseTutorialBoardVerticalCenterRatio: CGFloat = 0.50
    static let boardRowSpacingRatio: CGFloat = 0.23
    static let orderBannerWidth: CGFloat = 292
    static let tutorialPromptWidth: CGFloat = 300
    static let tutorialPromptHeight: CGFloat = 64
    static let horizontalInset: CGFloat = 28
    static let topControlInset: CGFloat = 6
    static let orderBannerTopInset: CGFloat = 22
    static let tutorialPromptBottomGap: CGFloat = 12
    static let bottomControlInset: CGFloat = -46
}

enum GameColor {
    static let potionBackground = Color(red: 0.09, green: 0.07, blue: 0.15)
    static let controlSurface = Color(red: 0.10, green: 0.08, blue: 0.15)
    static let controlMuted = Color(red: 0.28, green: 0.30, blue: 0.34)
    static let controlAccent = Color(red: 0.96, green: 0.73, blue: 0.29)
    static let hintAccent = Color(red: 0.72, green: 0.65, blue: 0.85)
    static let successAccent = Color(red: 0.53, green: 0.73, blue: 0.44)
    static let errorAccent = Color(red: 1.00, green: 0.25, blue: 0.22)
    static let glassFill = Color.white.opacity(0.14)
    static let glassStroke = Color(red: 0.87, green: 0.82, blue: 0.95)
    static let glassHighlight = Color.white.opacity(0.44)
    static let selectedStroke = Color(red: 1.00, green: 0.72, blue: 0.25)
    static let selectedGlow = Color(red: 0.72, green: 0.36, blue: 1.00)
    static let hintTarget = Color(red: 0.29, green: 0.91, blue: 0.96)
    static let lockedStroke = Color.white.opacity(0.44)
    static let lockedOverlay = Color(red: 0.06, green: 0.04, blue: 0.10).opacity(0.68)
    static let bonusFlaskGlow = Color(red: 1.00, green: 0.78, blue: 0.33)
    static let bonusFlaskWash = Color(red: 0.37, green: 0.22, blue: 0.08)
    static let invalid = Color(red: 1.00, green: 0.30, blue: 0.38)
}

extension LiquidColor {
    var swiftUIColor: Color {
        switch self {
        case .red:
            return .red
        case .green:
            return .green
        case .blue:
            return .blue
        case .yellow:
            return .yellow
        case .ruby:
            return Color(red: 0.94, green: 0.31, blue: 0.45)
        case .emerald:
            return Color(red: 0.32, green: 0.80, blue: 0.62)
        case .honey:
            return Color(red: 0.96, green: 0.74, blue: 0.26)
        case .moonBlue:
            return Color(red: 0.35, green: 0.56, blue: 0.92)
        case .violet:
            return Color(red: 0.66, green: 0.40, blue: 0.92)
        case .orange:
            return Color(red: 0.95, green: 0.49, blue: 0.25)
        case .rose:
            return Color(red: 0.95, green: 0.40, blue: 0.72)
        case .aqua:
            return Color(red: 0.31, green: 0.82, blue: 0.86)
        case .mint:
            return Color(red: 0.58, green: 0.90, blue: 0.54)
        case .amber:
            return Color(red: 0.94, green: 0.63, blue: 0.18)
        }
    }
}
