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
    static let lockedBonusIntroductionLevelID = 5

    let id: Int
    let difficulty: Difficulty
    let filledFlasks: [Flask]
    let availableEmptyFlaskCount: Int
    let hasLockedBonusFlask: Bool

    var validationIssues: [LevelValidationIssue] {
        var issues: [LevelValidationIssue] = []

        if availableEmptyFlaskCount != GameManager.startingEmptyFlaskCount {
            issues.append(
                LevelValidationIssue(
                    levelID: id,
                    message: "Level must start with \(GameManager.startingEmptyFlaskCount) available empty flasks."
                )
            )
        }

        if id >= Self.lockedBonusIntroductionLevelID && !hasLockedBonusFlask {
            issues.append(
                LevelValidationIssue(
                    levelID: id,
                    message: "Level \(Self.lockedBonusIntroductionLevelID)+ must include a locked bonus flask."
                )
            )
        }

        for (index, flask) in filledFlasks.enumerated() {
            if flask.kind != .regular {
                issues.append(
                    LevelValidationIssue(
                        levelID: id,
                        message: "Filled flask \(index) must be regular."
                    )
                )
            }

            if !flask.isFull {
                issues.append(
                    LevelValidationIssue(
                        levelID: id,
                        message: "Filled flask \(index) must contain \(Flask.maxCapacity) sections."
                    )
                )
            }
        }

        let colorCounts = filledFlasks
            .flatMap(\.colors)
            .reduce(into: [Color: Int]()) { counts, color in
                counts[color, default: 0] += 1
            }

        for count in colorCounts.values where count != Flask.maxCapacity {
            issues.append(
                LevelValidationIssue(
                    levelID: id,
                    message: "Every color must appear exactly \(Flask.maxCapacity) times."
                )
            )
            break
        }

        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }
}

protocol LevelRepository {
    var levels: [Level] { get }
    func level(at index: Int) -> Level
}

struct LevelValidationIssue: Equatable {
    let levelID: Int
    let message: String
}

struct LevelSolvabilityReport: Equatable {
    let isSolvable: Bool
    let minimumMoveCount: Int?
    let visitedStateCount: Int
}

struct LevelSolvabilityValidator {
    let maxVisitedStates: Int

    init(maxVisitedStates: Int = 250_000) {
        self.maxVisitedStates = maxVisitedStates
    }

    func canSolveWithoutBonusFlask(_ level: Level) -> Bool {
        reportWithoutBonusFlask(level).isSolvable
    }

    func reportWithoutBonusFlask(_ level: Level) -> LevelSolvabilityReport {
        guard level.isValid else {
            return LevelSolvabilityReport(
                isSolvable: false,
                minimumMoveCount: nil,
                visitedStateCount: 0
            )
        }

        let flasks = level.filledFlasks.map(\.colors)
            + Array(repeating: [], count: level.availableEmptyFlaskCount)
        return solve(SolverState(flasks: flasks))
    }

    private func solve(_ initialState: SolverState) -> LevelSolvabilityReport {
        if initialState.isSolved {
            return LevelSolvabilityReport(
                isSolvable: true,
                minimumMoveCount: 0,
                visitedStateCount: 1
            )
        }

        var visited: Set<SolverState> = [initialState.normalized()]
        var queue: [(state: SolverState, moveCount: Int)] = [
            (initialState, 0)
        ]
        var nextQueueIndex = 0

        while nextQueueIndex < queue.count && visited.count < maxVisitedStates {
            let item = queue[nextQueueIndex]
            nextQueueIndex += 1

            for move in item.state.validMoves {
                var nextState = item.state
                nextState.apply(move)

                let normalizedState = nextState.normalized()
                guard visited.insert(normalizedState).inserted else { continue }

                let nextMoveCount = item.moveCount + 1
                if normalizedState.isSolved {
                    return LevelSolvabilityReport(
                        isSolvable: true,
                        minimumMoveCount: nextMoveCount,
                        visitedStateCount: visited.count
                    )
                }

                queue.append((nextState, nextMoveCount))
            }
        }

        return LevelSolvabilityReport(
            isSolvable: false,
            minimumMoveCount: nil,
            visitedStateCount: visited.count
        )
    }
}

private struct SolverMove {
    let sourceIndex: Int
    let targetIndex: Int
    let color: Color
    let amount: Int
}

private struct SolverState: Hashable {
    var flasks: [[Color]]

    var isSolved: Bool {
        flasks.allSatisfy { flask in
            flask.isEmpty || (flask.count == Flask.maxCapacity && Set(flask).count == 1)
        }
    }

    var validMoves: [SolverMove] {
        flasks.indices.flatMap { sourceIndex in
            flasks.indices.compactMap { targetIndex in
                move(from: sourceIndex, to: targetIndex)
            }
        }
    }

    func normalized() -> SolverState {
        let sortedFlasks = flasks.sorted { lhs, rhs in
            Self.sortKey(for: lhs) < Self.sortKey(for: rhs)
        }

        return SolverState(flasks: sortedFlasks)
    }

    mutating func apply(_ move: SolverMove) {
        flasks[move.sourceIndex].removeLast(move.amount)
        flasks[move.targetIndex].append(
            contentsOf: Array(repeating: move.color, count: move.amount)
        )
    }

    private func move(from sourceIndex: Int, to targetIndex: Int) -> SolverMove? {
        guard sourceIndex != targetIndex else { return nil }

        let source = flasks[sourceIndex]
        let target = flasks[targetIndex]

        guard let sourceTopColor = source.last,
              target.count < Flask.maxCapacity else {
            return nil
        }

        if let targetTopColor = target.last, targetTopColor != sourceTopColor {
            return nil
        }

        let sourceRunCount = source
            .reversed()
            .prefix { $0 == sourceTopColor }
            .count
        let amount = min(sourceRunCount, Flask.maxCapacity - target.count)

        guard amount > 0 else { return nil }

        return SolverMove(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            color: sourceTopColor,
            amount: amount
        )
    }

    private static func sortKey(for flask: [Color]) -> String {
        flask.map(String.init(describing:)).joined(separator: "|")
    }
}

struct HandcraftedLevelRepository: LevelRepository {
    let levels: [Level]

    init() {
        self.levels = Self.makeLevels()
        precondition(
            levels.allSatisfy(\.isValid),
            "Handcrafted levels contain invalid data."
        )
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
        flasks.indices
            .flatMap { sourceIndex in
                flasks.indices.compactMap { targetIndex -> PourPlan? in
                    guard sourceIndex != targetIndex,
                          case let .success(plan) = pourPlan(from: sourceIndex, to: targetIndex) else {
                        return nil
                    }

                    return plan
                }
            }
            .max { hintScore(for: $0) < hintScore(for: $1) }
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

    private func hintScore(for plan: PourPlan) -> Int {
        let source = flasks[plan.sourceIndex]
        let target = flasks[plan.targetIndex]
        var score = plan.amount * 10

        if source.isSolved && !source.isEmpty {
            score -= 100
        }

        if target.isEmpty {
            score -= 8
        } else {
            score += 35
        }

        if source.colors.count == plan.amount {
            score += 12
        }

        if target.colors.count + plan.amount == Flask.maxCapacity {
            score += 24
        }

        return score
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
            hasLockedBonusFlask: id >= Level.lockedBonusIntroductionLevelID
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
