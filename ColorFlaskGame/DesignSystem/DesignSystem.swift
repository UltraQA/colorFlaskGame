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
    static let horizontalInset: CGFloat = 28
    static let topControlInset: CGFloat = 22
    static let bottomControlInset: CGFloat = 30
}

enum GameColor {
    static let potionBackground = Color(red: 0.13, green: 0.10, blue: 0.19)
    static let controlSurface = Color(red: 0.10, green: 0.08, blue: 0.15)
    static let controlMuted = Color(red: 0.28, green: 0.30, blue: 0.34)
    static let controlAccent = Color(red: 1.00, green: 0.72, blue: 0.25)
    static let successAccent = Color(red: 0.34, green: 0.93, blue: 0.66)
    static let glassFill = Color.white.opacity(0.14)
    static let glassStroke = Color(red: 0.87, green: 0.82, blue: 0.95)
    static let glassHighlight = Color.white.opacity(0.44)
    static let selectedStroke = Color(red: 1.00, green: 0.72, blue: 0.25)
    static let selectedGlow = Color(red: 0.72, green: 0.36, blue: 1.00)
    static let lockedStroke = Color.white.opacity(0.44)
    static let lockedOverlay = Color(red: 0.06, green: 0.04, blue: 0.10).opacity(0.68)
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
            return Color(red: 1.00, green: 0.32, blue: 0.48)
        case .emerald:
            return Color(red: 0.34, green: 0.88, blue: 0.68)
        case .honey:
            return Color(red: 1.00, green: 0.78, blue: 0.27)
        case .moonBlue:
            return Color(red: 0.33, green: 0.59, blue: 1.00)
        case .violet:
            return Color(red: 0.72, green: 0.43, blue: 1.00)
        case .orange:
            return Color(red: 1.00, green: 0.52, blue: 0.25)
        case .rose:
            return Color(red: 1.00, green: 0.42, blue: 0.77)
        case .aqua:
            return Color(red: 0.29, green: 0.91, blue: 0.96)
        }
    }
}
