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

struct ThemeTokenSet {
    let backgroundPrimary: Color
    let surface: Color
    let primaryAccent: Color
    let secondaryAccent: Color
    let softAccent: Color
    let textPrimary: Color
    let textOnAccent: Color
    let success: Color
    let danger: Color
}

enum ThemeCommerceState: Equatable {
    case owned
    case shop(herbsCost: Int, adPreviewAvailable: Bool)

    var title: String {
        switch self {
        case .owned:
            return "Owned"
        case let .shop(herbsCost, _):
            return "\(herbsCost)"
        }
    }
}

struct GameTheme: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let paletteHexCodes: [String]
    let tokens: ThemeTokenSet
    let commerceState: ThemeCommerceState

    var paletteColors: [Color] {
        paletteHexCodes.map { Color(hexCode: $0) ?? tokens.softAccent }
    }
}

enum GameThemeCatalog {
    static let base = GameTheme(
        id: "base-shop",
        name: "Base Shop",
        subtitle: "Current cozy potion room",
        paletteHexCodes: ["#170F26", "#1A1426", "#F5BA4A", "#87BA70", "#DED1F2"],
        tokens: ThemeTokenSet(
            backgroundPrimary: GameColor.potionBackground,
            surface: GameColor.controlSurface,
            primaryAccent: GameColor.controlAccent,
            secondaryAccent: GameColor.hintAccent,
            softAccent: GameColor.glassStroke,
            textPrimary: .white,
            textOnAccent: GameColor.controlSurface,
            success: GameColor.successAccent,
            danger: GameColor.errorAccent
        ),
        commerceState: .owned
    )

    static let shopThemes: [GameTheme] = [
        GameTheme(
            id: "spring-herb-basket",
            name: "Spring Herb Basket",
            subtitle: "Soft pastels and fresh herb light",
            paletteHexCodes: ["#F6F7C5", "#F6A78B", "#E7C4F0", "#A5C50B", "#E79494"],
            tokens: ThemeTokenSet(
                backgroundPrimary: Color(hex: 0xF6F7C5),
                surface: Color(hex: 0xE7C4F0),
                primaryAccent: Color(hex: 0xF6A78B),
                secondaryAccent: Color(hex: 0xE79494),
                softAccent: Color(hex: 0xF7EED8),
                textPrimary: Color(hex: 0x2F2638),
                textOnAccent: Color(hex: 0x2F2638),
                success: Color(hex: 0xA5C50B),
                danger: Color(hex: 0xD84F65)
            ),
            commerceState: .shop(herbsCost: 120, adPreviewAvailable: true)
        ),
        GameTheme(
            id: "moonlit-elixir",
            name: "Moonlit Elixir",
            subtitle: "Deep violet shelves with golden magic",
            paletteHexCodes: ["#4F386D", "#FFD966", "#D6C9D8", "#160723", "#EEEEEE"],
            tokens: ThemeTokenSet(
                backgroundPrimary: Color(hex: 0x160723),
                surface: Color(hex: 0x4F386D),
                primaryAccent: Color(hex: 0xFFD966),
                secondaryAccent: Color(hex: 0xD6C9D8),
                softAccent: Color(hex: 0xD6C9D8),
                textPrimary: Color(hex: 0xEEEEEE),
                textOnAccent: Color(hex: 0x160723),
                success: Color(hex: 0x63E6A2),
                danger: Color(hex: 0xFF5A6F)
            ),
            commerceState: .shop(herbsCost: 220, adPreviewAvailable: true)
        )
    ]

    static let allThemes = [base] + shopThemes

    static func theme(id: String) -> GameTheme? {
        allThemes.first { $0.id == id }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }

    init?(hexCode: String) {
        let cleanedHex = hexCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleanedHex.count == 6,
              let value = UInt32(cleanedHex, radix: 16) else {
            return nil
        }

        self.init(hex: value)
    }
}

private struct GameThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = GameThemeCatalog.base.tokens
}

extension EnvironmentValues {
    var gameTheme: ThemeTokenSet {
        get { self[GameThemeEnvironmentKey.self] }
        set { self[GameThemeEnvironmentKey.self] = newValue }
    }
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
