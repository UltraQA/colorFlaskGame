import AudioToolbox
import Combine
import Foundation
import UIKit

enum GameFeedbackEvent: Equatable {
    case uiTap
    case flaskSelect
    case validPour
    case invalidMove
    case levelComplete
    case hintUsed
    case undo
    case reset
    case toggleOn
    case toggleOff
}

enum HintAnalyticsPayment: Equatable {
    case free
    case herbs
    case rewardedAd
}

enum BonusFlaskUnlockMethod: Equatable {
    case rewardedAd
    case permanentPurchase
}

enum GameAnalyticsEvent: Equatable {
    case levelStarted(levelNumber: Int)
    case levelCompleted(levelNumber: Int, moves: Int, herbsReward: Int?)
    case hintUsed(levelNumber: Int, payment: HintAnalyticsPayment)
    case undoUsed(levelNumber: Int)
    case resetRequested(levelNumber: Int)
    case resetConfirmed(levelNumber: Int)
    case bonusFlaskPromptShown(levelNumber: Int)
    case rewardedAdStarted(levelNumber: Int, placement: RewardedAdPlacement)
    case rewardedAdCompleted(levelNumber: Int, placement: RewardedAdPlacement, success: Bool)
    case bonusFlaskUnlockStarted(levelNumber: Int, method: BonusFlaskUnlockMethod)
    case bonusFlaskUnlockCompleted(levelNumber: Int, method: BonusFlaskUnlockMethod, success: Bool)
}

@MainActor
protocol GameAnalyticsProviding: AnyObject {
    func track(_ event: GameAnalyticsEvent)
}

@MainActor
final class NoOpGameAnalyticsProvider: GameAnalyticsProviding {
    func track(_ event: GameAnalyticsEvent) {}
}

enum GameCrashContextKey: String {
    case currentFlow
    case currentLevel
    case herbsBalance
}

@MainActor
protocol GameCrashReportingProviding: AnyObject {
    func configure()
    func setContextValue(_ value: String?, for key: GameCrashContextKey)
    func record(_ error: any Error, metadata: [String: String])
}

@MainActor
final class NoOpGameCrashReporter: GameCrashReportingProviding {
    func configure() {}
    func setContextValue(_ value: String?, for key: GameCrashContextKey) {}
    func record(_ error: any Error, metadata: [String: String] = [:]) {}
}

@MainActor
protocol GameFeedbackProviding: AnyObject {
    func play(_ event: GameFeedbackEvent)
}

@MainActor
final class NoOpGameFeedbackProvider: GameFeedbackProviding {
    func play(_ event: GameFeedbackEvent) {}
}

@MainActor
final class SystemGameFeedbackProvider: ObservableObject, GameFeedbackProviding {
    @Published private(set) var isSoundEnabled: Bool {
        didSet {
            progressStore.isSoundEnabled = isSoundEnabled
        }
    }

    @Published private(set) var isHapticsEnabled: Bool {
        didSet {
            progressStore.isHapticsEnabled = isHapticsEnabled
        }
    }

    private var progressStore: any ProgressStore

    init(progressStore: any ProgressStore = UserDefaultsProgressStore()) {
        self.progressStore = progressStore
        self.isSoundEnabled = progressStore.isSoundEnabled
        self.isHapticsEnabled = progressStore.isHapticsEnabled
    }

    func toggleSound() {
        isSoundEnabled.toggle()
        play(isSoundEnabled ? .toggleOn : .toggleOff)
    }

    func toggleHaptics() {
        isHapticsEnabled.toggle()
        play(isHapticsEnabled ? .toggleOn : .toggleOff)
    }

    func play(_ event: GameFeedbackEvent) {
        if isSoundEnabled {
            AudioServicesPlaySystemSound(event.soundID)
        }

        guard isHapticsEnabled else { return }

        switch event {
        case .levelComplete:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .invalidMove:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .flaskSelect, .hintUsed:
            UISelectionFeedbackGenerator().selectionChanged()
        case .validPour, .reset:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .uiTap, .undo, .toggleOn, .toggleOff:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

private extension GameFeedbackEvent {
    var soundID: SystemSoundID {
        switch self {
        case .uiTap, .undo, .toggleOn, .toggleOff:
            return 1104
        case .flaskSelect:
            return 1057
        case .validPour:
            return 1103
        case .invalidMove:
            return 1053
        case .levelComplete:
            return 1025
        case .hintUsed:
            return 1016
        case .reset:
            return 1155
        }
    }
}
