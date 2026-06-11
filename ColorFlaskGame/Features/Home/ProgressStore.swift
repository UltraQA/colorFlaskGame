import Foundation

struct ActiveRoundSnapshot: Codable, Equatable {
    let levelIndex: Int
    let flasks: [Flask]
    let moves: Int
    let history: [[Flask]]
    let hintsUsedThisLevel: Int
    let rewardedHintCredits: Int

    init(
        levelIndex: Int,
        flasks: [Flask],
        moves: Int,
        history: [[Flask]],
        hintsUsedThisLevel: Int = 0,
        rewardedHintCredits: Int = 0
    ) {
        self.levelIndex = levelIndex
        self.flasks = flasks
        self.moves = moves
        self.history = history
        self.hintsUsedThisLevel = hintsUsedThisLevel
        self.rewardedHintCredits = rewardedHintCredits
    }

    private enum CodingKeys: String, CodingKey {
        case levelIndex
        case flasks
        case moves
        case history
        case hintsUsedThisLevel
        case rewardedHintCredits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        levelIndex = try container.decode(Int.self, forKey: .levelIndex)
        flasks = try container.decode([Flask].self, forKey: .flasks)
        moves = try container.decode(Int.self, forKey: .moves)
        history = try container.decode([[Flask]].self, forKey: .history)
        hintsUsedThisLevel = try container.decodeIfPresent(
            Int.self,
            forKey: .hintsUsedThisLevel
        ) ?? 0
        rewardedHintCredits = try container.decodeIfPresent(
            Int.self,
            forKey: .rewardedHintCredits
        ) ?? 0
    }
}

protocol ProgressStore {
    var currentLevelIndex: Int { get set }
    var activeRoundSnapshot: ActiveRoundSnapshot? { get set }
    var isBonusFlaskPermanentlyUnlocked: Bool { get set }
    var herbsBalance: Int { get set }
    var hasCompletedOnboarding: Bool { get set }
    var hasSeenHerbsTutorial: Bool { get set }
    var isSoundEnabled: Bool { get set }
    var isHapticsEnabled: Bool { get set }
}

struct UserDefaultsProgressStore: ProgressStore {
    private enum Key {
        static let currentLevelIndex = "waterSort.progress.currentLevelIndex"
        static let activeRoundSnapshot = "waterSort.progress.activeRoundSnapshot"
        static let bonusFlaskPurchase = "waterSort.bonusFlask.isPermanentlyUnlocked"
        static let herbsBalance = "waterSort.economy.herbsBalance"
        static let hasCompletedOnboarding = "waterSort.onboarding.hasCompleted"
        static let hasSeenHerbsTutorial = "waterSort.onboarding.hasSeenHerbsTutorial"
        static let isSoundEnabled = "waterSort.settings.isSoundEnabled"
        static let isHapticsEnabled = "waterSort.settings.isHapticsEnabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentLevelIndex: Int {
        get {
            userDefaults.integer(forKey: Key.currentLevelIndex)
        }
        set {
            userDefaults.set(newValue, forKey: Key.currentLevelIndex)
        }
    }

    var activeRoundSnapshot: ActiveRoundSnapshot? {
        get {
            guard let data = userDefaults.data(forKey: Key.activeRoundSnapshot) else { return nil }
            return try? JSONDecoder().decode(ActiveRoundSnapshot.self, from: data)
        }
        set {
            guard let newValue else {
                userDefaults.removeObject(forKey: Key.activeRoundSnapshot)
                return
            }

            guard let data = try? JSONEncoder().encode(newValue) else { return }
            userDefaults.set(data, forKey: Key.activeRoundSnapshot)
        }
    }

    var isBonusFlaskPermanentlyUnlocked: Bool {
        get {
            userDefaults.bool(forKey: Key.bonusFlaskPurchase)
        }
        set {
            userDefaults.set(newValue, forKey: Key.bonusFlaskPurchase)
        }
    }

    var herbsBalance: Int {
        get {
            userDefaults.integer(forKey: Key.herbsBalance)
        }
        set {
            userDefaults.set(newValue, forKey: Key.herbsBalance)
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            userDefaults.bool(forKey: Key.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Key.hasCompletedOnboarding)
        }
    }

    var isSoundEnabled: Bool {
        get {
            userDefaults.object(forKey: Key.isSoundEnabled) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Key.isSoundEnabled)
        }
    }

    var hasSeenHerbsTutorial: Bool {
        get {
            userDefaults.bool(forKey: Key.hasSeenHerbsTutorial)
        }
        set {
            userDefaults.set(newValue, forKey: Key.hasSeenHerbsTutorial)
        }
    }

    var isHapticsEnabled: Bool {
        get {
            userDefaults.object(forKey: Key.isHapticsEnabled) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Key.isHapticsEnabled)
        }
    }
}
