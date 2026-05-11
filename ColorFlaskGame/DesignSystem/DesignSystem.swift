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
