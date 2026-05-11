import SwiftUI

enum FlaskKind: Equatable {
    case regular
    case bonus
}

struct Flask: Identifiable, Equatable {
    static let maxCapacity = 4

    let id: UUID
    let kind: FlaskKind
    private(set) var colors: [Color]
    private(set) var isUnlocked: Bool

    init(
        id: UUID = UUID(),
        kind: FlaskKind = .regular,
        colors: [Color] = [],
        isUnlocked: Bool = true
    ) {
        precondition(colors.count <= Self.maxCapacity, "Flask cannot exceed max capacity")
        self.id = id
        self.kind = kind
        self.colors = colors
        self.isUnlocked = isUnlocked
    }

    var isPlayable: Bool {
        isUnlocked
    }

    var isBonus: Bool {
        kind == .bonus
    }

    var isEmpty: Bool {
        colors.isEmpty
    }

    var isFull: Bool {
        colors.count == Self.maxCapacity
    }

    var freeSpace: Int {
        Self.maxCapacity - colors.count
    }

    var topColor: Color? {
        colors.last
    }

    var topSameColorCount: Int {
        guard let topColor else { return 0 }

        return colors
            .reversed()
            .prefix { $0 == topColor }
            .count
    }

    var isSolved: Bool {
        isEmpty || (isFull && Set(colors).count == 1)
    }

    mutating func push(_ color: Color) {
        guard isPlayable, !isFull else { return }
        colors.append(color)
    }

    mutating func pop() -> Color? {
        guard isPlayable else { return nil }
        return colors.popLast()
    }

    mutating func unlock() {
        isUnlocked = true
    }
}

enum PourError: LocalizedError, Equatable {
    case sameFlask
    case flaskIsLocked
    case sourceIsEmpty
    case targetIsFull
    case colorMismatch
    case invalidFlaskIndex

    var errorDescription: String? {
        switch self {
        case .sameFlask:
            return "Cannot pour into the same flask."
        case .flaskIsLocked:
            return "This flask is locked."
        case .sourceIsEmpty:
            return "Cannot pour from an empty flask."
        case .targetIsFull:
            return "Target flask is full."
        case .colorMismatch:
            return "Liquid can only be poured into an empty flask or onto the same color."
        case .invalidFlaskIndex:
            return "Selected flask does not exist."
        }
    }
}

struct PourPlan: Equatable {
    let sourceIndex: Int
    let targetIndex: Int
    let color: Color
    let amount: Int
}

enum Difficulty: String, Equatable {
    case tutorial
    case easy
    case medium
}

struct Level: Identifiable, Equatable {
    let id: Int
    let difficulty: Difficulty
    let filledFlasks: [Flask]
    let availableEmptyFlaskCount: Int
    let hasLockedBonusFlask: Bool
}

protocol LevelRepository {
    var levels: [Level] { get }
    func level(at index: Int) -> Level
}

struct HandcraftedLevelRepository: LevelRepository {
    let levels: [Level]

    init() {
        self.levels = Self.makeLevels()
    }

    func level(at index: Int) -> Level {
        guard !levels.isEmpty else {
            preconditionFailure("Level repository must contain at least one level")
        }

        return levels[index % levels.count]
    }
}

final class GameManager: ObservableObject {
    static let defaultFilledFlaskCount = 5
    static let startingEmptyFlaskCount = 2
    static let bonusEmptyFlaskCount = 1
    static let defaultFlaskCount = defaultFilledFlaskCount + startingEmptyFlaskCount + bonusEmptyFlaskCount

    @Published private(set) var flasks: [Flask]
    let level: Level?

    init(flasks: [Flask], level: Level? = nil) {
        self.flasks = flasks
        self.level = level
    }

    static func makeInitialLevel(
        filledFlaskCount: Int? = nil,
        levelIndex: Int = 0,
        levelRepository: LevelRepository = HandcraftedLevelRepository(),
        isBonusFlaskUnlocked: Bool = false
    ) -> GameManager {
        if let filledFlaskCount {
            return makeGeneratedLevel(
                filledFlaskCount: filledFlaskCount,
                isBonusFlaskUnlocked: isBonusFlaskUnlocked
            )
        }

        let level = levelRepository.level(at: levelIndex)
        return GameManager(
            flasks: makeFlasks(from: level, isBonusFlaskUnlocked: isBonusFlaskUnlocked),
            level: level
        )
    }

    private static func makeGeneratedLevel(
        filledFlaskCount: Int = defaultFilledFlaskCount,
        isBonusFlaskUnlocked: Bool = false
    ) -> GameManager {
        precondition(filledFlaskCount > 0, "Level must contain at least one filled flask")

        let colorCount = filledFlaskCount
        let colors = Array(levelPalette.prefix(colorCount))
        precondition(colors.count == colorCount, "Not enough colors in level palette")

        let sections = colors.flatMap { color in
            Array(repeating: color, count: Flask.maxCapacity)
        }

        var flasks = sections
            .shuffled()
            .chunked(into: Flask.maxCapacity)
            .map { Flask(colors: $0) }

        flasks.append(contentsOf: (0..<startingEmptyFlaskCount).map { _ in Flask() })
        flasks.append(
            Flask(
                kind: .bonus,
                colors: [],
                isUnlocked: isBonusFlaskUnlocked
            )
        )

        return GameManager(flasks: flasks)
    }

    private static func makeFlasks(from level: Level, isBonusFlaskUnlocked: Bool) -> [Flask] {
        var flasks = level.filledFlasks
        flasks.append(contentsOf: (0..<level.availableEmptyFlaskCount).map { _ in Flask() })

        if level.hasLockedBonusFlask {
            flasks.append(
                Flask(
                    kind: .bonus,
                    colors: [],
                    isUnlocked: isBonusFlaskUnlocked
                )
            )
        }

        return flasks
    }

    var isRoundCompleted: Bool {
        flasks
            .filter(\.isPlayable)
            .allSatisfy(\.isSolved)
    }

    var playableFlasks: [Flask] {
        flasks.filter(\.isPlayable)
    }

    func restore(flasks: [Flask]) {
        self.flasks = flasks
    }

    func unlockBonusFlaskForCurrentRound() {
        guard let bonusIndex = flasks.firstIndex(where: { $0.isBonus }) else { return }
        flasks[bonusIndex].unlock()
    }

    func firstValidMove() -> PourPlan? {
        for sourceIndex in flasks.indices {
            for targetIndex in flasks.indices where sourceIndex != targetIndex {
                if case let .success(plan) = pourPlan(from: sourceIndex, to: targetIndex) {
                    return plan
                }
            }
        }

        return nil
    }

    func pourPlan(from sourceIndex: Int, to targetIndex: Int) -> Result<PourPlan, PourError> {
        guard flasks.indices.contains(sourceIndex),
              flasks.indices.contains(targetIndex) else {
            return .failure(.invalidFlaskIndex)
        }

        guard sourceIndex != targetIndex else {
            return .failure(.sameFlask)
        }

        let source = flasks[sourceIndex]
        let target = flasks[targetIndex]

        guard source.isPlayable, target.isPlayable else {
            return .failure(.flaskIsLocked)
        }

        guard let sourceTopColor = source.topColor else {
            return .failure(.sourceIsEmpty)
        }

        guard !target.isFull else {
            return .failure(.targetIsFull)
        }

        if let targetTopColor = target.topColor, targetTopColor != sourceTopColor {
            return .failure(.colorMismatch)
        }

        let amountToPour = min(source.topSameColorCount, target.freeSpace)
        guard amountToPour > 0 else {
            return .failure(.targetIsFull)
        }

        return .success(
            PourPlan(
                sourceIndex: sourceIndex,
                targetIndex: targetIndex,
                color: sourceTopColor,
                amount: amountToPour
            )
        )
    }

    @discardableResult
    func pour(from sourceIndex: Int, to targetIndex: Int) -> Result<Int, PourError> {
        let planResult = pourPlan(from: sourceIndex, to: targetIndex)
        guard case let .success(plan) = planResult else {
            return planResult.map(\.amount)
        }

        for _ in 0..<plan.amount {
            _ = flasks[sourceIndex].pop()
            flasks[targetIndex].push(plan.color)
        }

        return .success(plan.amount)
    }

    private static let levelPalette: [Color] = [
        Color(red: 1.00, green: 0.32, blue: 0.48),
        Color(red: 0.34, green: 0.88, blue: 0.68),
        Color(red: 1.00, green: 0.78, blue: 0.27),
        Color(red: 0.33, green: 0.59, blue: 1.00),
        Color(red: 0.72, green: 0.43, blue: 1.00),
        Color(red: 1.00, green: 0.52, blue: 0.25),
        Color(red: 1.00, green: 0.42, blue: 0.77),
        Color(red: 0.29, green: 0.91, blue: 0.96)
    ]
}

private extension HandcraftedLevelRepository {
    static func makeLevels() -> [Level] {
        [
            makeLevel(
                id: 1,
                difficulty: .tutorial,
                rows: [
                    [0, 0, 1, 1],
                    [1, 1, 2, 2],
                    [2, 2, 0, 0]
                ]
            ),
            makeLevel(
                id: 2,
                difficulty: .tutorial,
                rows: [
                    [0, 1, 0, 1],
                    [1, 2, 1, 2],
                    [2, 0, 2, 0]
                ]
            ),
            makeLevel(
                id: 3,
                difficulty: .tutorial,
                rows: [
                    [0, 1, 0, 2],
                    [1, 2, 3, 0],
                    [2, 3, 1, 3],
                    [3, 0, 2, 1]
                ]
            ),
            makeLevel(
                id: 4,
                difficulty: .easy,
                rows: [
                    [0, 1, 2, 3],
                    [1, 0, 3, 2],
                    [2, 3, 0, 1],
                    [3, 2, 1, 0]
                ]
            ),
            makeLevel(
                id: 5,
                difficulty: .easy,
                rows: [
                    [0, 1, 2, 0],
                    [1, 2, 3, 1],
                    [2, 3, 4, 2],
                    [3, 4, 0, 3],
                    [4, 0, 1, 4]
                ]
            ),
            makeLevel(
                id: 6,
                difficulty: .easy,
                rows: [
                    [0, 1, 0, 2],
                    [1, 2, 1, 3],
                    [2, 3, 2, 4],
                    [3, 4, 3, 0],
                    [4, 0, 4, 1]
                ]
            ),
            makeLevel(
                id: 7,
                difficulty: .easy,
                rows: [
                    [0, 2, 1, 3],
                    [1, 3, 2, 4],
                    [2, 4, 3, 0],
                    [3, 0, 4, 1],
                    [4, 1, 0, 2]
                ]
            ),
            makeLevel(
                id: 8,
                difficulty: .medium,
                rows: [
                    [0, 1, 2, 3],
                    [1, 2, 3, 4],
                    [2, 3, 4, 0],
                    [3, 4, 0, 1],
                    [4, 0, 1, 2]
                ]
            ),
            makeLevel(
                id: 9,
                difficulty: .medium,
                rows: [
                    [0, 2, 4, 1],
                    [1, 3, 0, 2],
                    [2, 4, 1, 3],
                    [3, 0, 2, 4],
                    [4, 1, 3, 0]
                ]
            ),
            makeLevel(
                id: 10,
                difficulty: .medium,
                rows: [
                    [0, 3, 1, 4],
                    [1, 4, 2, 0],
                    [2, 0, 3, 1],
                    [3, 1, 4, 2],
                    [4, 2, 0, 3]
                ]
            )
        ]
    }

    static func makeLevel(id: Int, difficulty: Difficulty, rows: [[Int]]) -> Level {
        Level(
            id: id,
            difficulty: difficulty,
            filledFlasks: rows.map { row in
                Flask(colors: row.map { palette[$0] })
            },
            availableEmptyFlaskCount: GameManager.startingEmptyFlaskCount,
            hasLockedBonusFlask: true
        )
    }

    static let palette: [Color] = [
        Color(red: 1.00, green: 0.32, blue: 0.48),
        Color(red: 0.34, green: 0.88, blue: 0.68),
        Color(red: 1.00, green: 0.78, blue: 0.27),
        Color(red: 0.33, green: 0.59, blue: 1.00),
        Color(red: 0.72, green: 0.43, blue: 1.00)
    ]
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
