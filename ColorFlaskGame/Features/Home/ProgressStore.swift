import Foundation

protocol ProgressStore {
    var currentLevelIndex: Int { get set }
    var isBonusFlaskPermanentlyUnlocked: Bool { get set }
    var herbsBalance: Int { get set }
}

struct UserDefaultsProgressStore: ProgressStore {
    private enum Key {
        static let currentLevelIndex = "waterSort.progress.currentLevelIndex"
        static let bonusFlaskPurchase = "waterSort.bonusFlask.isPermanentlyUnlocked"
        static let herbsBalance = "waterSort.economy.herbsBalance"
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
}
