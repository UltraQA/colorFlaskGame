import Combine
import Foundation

enum LiquidColor: String, CaseIterable, Codable, Hashable {
    case red
    case green
    case blue
    case yellow
    case ruby
    case emerald
    case honey
    case moonBlue
    case violet
    case orange
    case rose
    case aqua

    var accessibilityName: String {
        switch self {
        case .red:
            return "red"
        case .green:
            return "green"
        case .blue:
            return "blue"
        case .yellow:
            return "yellow"
        case .ruby:
            return "ruby"
        case .emerald:
            return "emerald"
        case .honey:
            return "honey"
        case .moonBlue:
            return "moon blue"
        case .violet:
            return "violet"
        case .orange:
            return "orange"
        case .rose:
            return "rose"
        case .aqua:
            return "aqua"
        }
    }
}

enum FlaskKind: Equatable {
    case regular
    case bonus
}

struct Flask: Identifiable, Equatable {
    static let maxCapacity = 4

    let id: UUID
    let kind: FlaskKind
    private(set) var colors: [LiquidColor]
    private(set) var isUnlocked: Bool

    init(
        id: UUID = UUID(),
        kind: FlaskKind = .regular,
        colors: [LiquidColor] = [],
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

    var topColor: LiquidColor? {
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

    mutating func push(_ color: LiquidColor) {
        guard isPlayable, !isFull else { return }
        colors.append(color)
    }

    mutating func pop() -> LiquidColor? {
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
    let color: LiquidColor
    let amount: Int
}

enum Difficulty: String, Equatable {
    case tutorial
    case easy
    case medium
}

enum LevelObjective: Equatable {
    case sortAll
    case completeColor(LiquidColor)
}

struct CustomerOrder: Equatable {
    let customerName: String
    let potionName: String
    let targetColor: LiquidColor
    let rewardHerbs: Int
    let shortCopy: String
}

enum DeadEndRisk: String, Equatable {
    case low
    case medium
    case high
}

struct LevelDifficultyMetrics: Equatable {
    let colorCount: Int
    let minimumMoveCount: Int?
    let bufferPressure: Int
    let solutionDepth: Int?
    let deadEndRisk: DeadEndRisk
    let visitedStateCount: Int
}

struct Level: Identifiable, Equatable {
    static let lockedBonusIntroductionLevelID = 5

    let id: Int
    let difficulty: Difficulty
    let filledFlasks: [Flask]
    let availableEmptyFlaskCount: Int
    let hasLockedBonusFlask: Bool
    let objective: LevelObjective
    let customerOrder: CustomerOrder?

    init(
        id: Int,
        difficulty: Difficulty,
        filledFlasks: [Flask],
        availableEmptyFlaskCount: Int,
        hasLockedBonusFlask: Bool,
        objective: LevelObjective = .sortAll,
        customerOrder: CustomerOrder? = nil
    ) {
        self.id = id
        self.difficulty = difficulty
        self.filledFlasks = filledFlasks
        self.availableEmptyFlaskCount = availableEmptyFlaskCount
        self.hasLockedBonusFlask = hasLockedBonusFlask
        self.objective = objective
        self.customerOrder = customerOrder
    }

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
            .reduce(into: [LiquidColor: Int]()) { counts, color in
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

        if case let .completeColor(targetColor) = objective,
           colorCounts[targetColor, default: 0] < Flask.maxCapacity {
            issues.append(
                LevelValidationIssue(
                    levelID: id,
                    message: "Order objective target color must appear at least \(Flask.maxCapacity) times."
                )
            )
        }

        if let customerOrder, case let .completeColor(targetColor) = objective,
           customerOrder.targetColor != targetColor {
            issues.append(
                LevelValidationIssue(
                    levelID: id,
                    message: "Customer order target color must match the level objective."
                )
            )
        }

        return issues
    }

    var isValid: Bool {
        validationIssues.isEmpty
    }

    func difficultyMetrics(
        validator: LevelSolvabilityValidator = LevelSolvabilityValidator()
    ) -> LevelDifficultyMetrics {
        let report = validator.reportWithoutBonusFlask(self)
        let colors = Set(filledFlasks.flatMap(\.colors))
        let bufferPressure = max(0, colors.count - availableEmptyFlaskCount)

        return LevelDifficultyMetrics(
            colorCount: colors.count,
            minimumMoveCount: report.minimumMoveCount,
            bufferPressure: bufferPressure,
            solutionDepth: report.minimumMoveCount,
            deadEndRisk: Self.deadEndRisk(from: report),
            visitedStateCount: report.visitedStateCount
        )
    }

    private static func deadEndRisk(from report: LevelSolvabilityReport) -> DeadEndRisk {
        guard report.isSolvable else { return .high }

        switch report.visitedStateCount {
        case 0..<1_000:
            return .low
        case 1_000..<10_000:
            return .medium
        default:
            return .high
        }
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

struct SolutionHintReport: Equatable {
    let firstMove: PourPlan?
    let solutionMoveCount: Int?
    let visitedStateCount: Int

    var foundSolution: Bool {
        firstMove != nil
    }
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

struct SolutionHintSolver {
    let maxVisitedStates: Int

    init(maxVisitedStates: Int = 75_000) {
        self.maxVisitedStates = maxVisitedStates
    }

    func nextMove(for flasks: [Flask]) -> SolutionHintReport {
        let playableFlasks = flasks.enumerated()
            .filter { $0.element.isPlayable }

        let originalIndices = playableFlasks.map(\.offset)
        let initialState = SolverState(flasks: playableFlasks.map(\.element.colors))

        guard !initialState.isSolved else {
            return SolutionHintReport(
                firstMove: nil,
                solutionMoveCount: 0,
                visitedStateCount: 1
            )
        }

        var visited: Set<SolverState> = [initialState.normalized()]
        var queue: [(state: SolverState, firstMove: SolverMove?, moveCount: Int)] = [
            (initialState, nil, 0)
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

                let firstMove = item.firstMove ?? move
                let nextMoveCount = item.moveCount + 1
                if normalizedState.isSolved {
                    return SolutionHintReport(
                        firstMove: PourPlan(
                            sourceIndex: originalIndices[firstMove.sourceIndex],
                            targetIndex: originalIndices[firstMove.targetIndex],
                            color: firstMove.color,
                            amount: firstMove.amount
                        ),
                        solutionMoveCount: nextMoveCount,
                        visitedStateCount: visited.count
                    )
                }

                queue.append((nextState, firstMove, nextMoveCount))
            }
        }

        return SolutionHintReport(
            firstMove: nil,
            solutionMoveCount: nil,
            visitedStateCount: visited.count
        )
    }
}

private struct SolverMove {
    let sourceIndex: Int
    let targetIndex: Int
    let color: LiquidColor
    let amount: Int
}

private struct SolverState: Hashable {
    var flasks: [[LiquidColor]]

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

    private static func sortKey(for flask: [LiquidColor]) -> String {
        flask.map(\.rawValue).joined(separator: "|")
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

        guard index >= levels.count else {
            return levels[index]
        }

        return Self.makeGeneratedLevel(id: index + 1)
    }
}

struct GameState: Equatable {
    private(set) var flasks: [Flask]
    let level: Level?

    init(flasks: [Flask], level: Level? = nil) {
        self.flasks = flasks
        self.level = level
    }

    var isRoundCompleted: Bool {
        switch level?.objective ?? .sortAll {
        case .sortAll:
            return flasks
                .filter(\.isPlayable)
                .allSatisfy(\.isSolved)
        case let .completeColor(targetColor):
            return flasks
                .filter(\.isPlayable)
                .contains { flask in
                    flask.isFull && flask.colors.allSatisfy { $0 == targetColor }
                }
        }
    }

    var playableFlasks: [Flask] {
        flasks.filter(\.isPlayable)
    }

    mutating func restore(flasks: [Flask]) {
        self.flasks = flasks
    }

    mutating func unlockBonusFlaskForCurrentRound() {
        guard let bonusIndex = flasks.firstIndex(where: { $0.isBonus }) else { return }
        flasks[bonusIndex].unlock()
    }

    func firstValidMove() -> PourPlan? {
        solutionHintReport().firstMove ?? bestLocalMove()
    }

    func solutionHintReport(maxVisitedStates: Int = 75_000) -> SolutionHintReport {
        SolutionHintSolver(maxVisitedStates: maxVisitedStates)
            .nextMove(for: flasks)
    }

    private func bestLocalMove() -> PourPlan? {
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
    mutating func pour(from sourceIndex: Int, to targetIndex: Int) -> Result<Int, PourError> {
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
}

final class GameManager: ObservableObject {
    static let defaultFilledFlaskCount = 5
    static let startingEmptyFlaskCount = 2
    static let bonusEmptyFlaskCount = 1
    static let defaultFlaskCount = defaultFilledFlaskCount + startingEmptyFlaskCount + bonusEmptyFlaskCount

    @Published private var state: GameState

    var flasks: [Flask] {
        state.flasks
    }

    var level: Level? {
        state.level
    }

    init(state: GameState) {
        self.state = state
    }

    convenience init(flasks: [Flask], level: Level? = nil) {
        self.init(state: GameState(flasks: flasks, level: level))
    }

    static func makeInitialLevel(
        filledFlaskCount: Int? = nil,
        levelIndex: Int = 0,
        levelRepository: LevelRepository = HandcraftedLevelRepository(),
        isBonusFlaskUnlocked: Bool = false,
        generatedLevelSeed: UInt64? = nil
    ) -> GameManager {
        if let filledFlaskCount {
            return makeGeneratedLevel(
                filledFlaskCount: filledFlaskCount,
                isBonusFlaskUnlocked: isBonusFlaskUnlocked,
                seed: generatedLevelSeed ?? UInt64(levelIndex + 1)
            )
        }

        let level = levelRepository.level(at: levelIndex)
        return GameManager(
            state: GameState(
                flasks: makeFlasks(from: level, isBonusFlaskUnlocked: isBonusFlaskUnlocked),
                level: level
            )
        )
    }

    private static func makeGeneratedLevel(
        filledFlaskCount: Int = defaultFilledFlaskCount,
        isBonusFlaskUnlocked: Bool = false,
        seed: UInt64
    ) -> GameManager {
        precondition(filledFlaskCount > 0, "Level must contain at least one filled flask")

        let colorCount = filledFlaskCount
        let colors = Array(levelPalette.prefix(colorCount))
        precondition(colors.count == colorCount, "Not enough colors in level palette")

        let sections = colors.flatMap { color in
            Array(repeating: color, count: Flask.maxCapacity)
        }

        var randomNumberGenerator = SeededRandomNumberGenerator(seed: seed)
        var flasks = sections
            .shuffled(using: &randomNumberGenerator)
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

        return GameManager(state: GameState(flasks: flasks))
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
        state.isRoundCompleted
    }

    var playableFlasks: [Flask] {
        state.playableFlasks
    }

    func restore(flasks: [Flask]) {
        updateState { state in
            state.restore(flasks: flasks)
        }
    }

    func unlockBonusFlaskForCurrentRound() {
        updateState { state in
            state.unlockBonusFlaskForCurrentRound()
        }
    }

    func firstValidMove() -> PourPlan? {
        state.firstValidMove()
    }

    func solutionHintReport(maxVisitedStates: Int = 75_000) -> SolutionHintReport {
        state.solutionHintReport(maxVisitedStates: maxVisitedStates)
    }

    func pourPlan(from sourceIndex: Int, to targetIndex: Int) -> Result<PourPlan, PourError> {
        state.pourPlan(from: sourceIndex, to: targetIndex)
    }

    @discardableResult
    func pour(from sourceIndex: Int, to targetIndex: Int) -> Result<Int, PourError> {
        var nextState = state
        let result = nextState.pour(from: sourceIndex, to: targetIndex)
        state = nextState
        return result
    }

    private static let levelPalette: [LiquidColor] = [
        .ruby,
        .emerald,
        .honey,
        .moonBlue,
        .violet,
        .orange,
        .rose,
        .aqua
    ]

    private func updateState(_ transform: (inout GameState) -> Void) {
        var nextState = state
        transform(&nextState)
        state = nextState
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
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
                ],
                objective: .completeColor(palette[2]),
                customerOrder: makeOrder(
                    customerName: "Mira",
                    potionName: "Luck Potion",
                    targetColor: palette[2],
                    shortCopy: "Brew one bright luck potion."
                )
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
                ],
                objective: .completeColor(palette[3]),
                customerOrder: makeOrder(
                    customerName: "Rowan",
                    potionName: "Moonwater Draught",
                    targetColor: palette[3],
                    shortCopy: "Bottle a cool moonwater draught."
                )
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
                ],
                objective: .completeColor(palette[4]),
                customerOrder: makeOrder(
                    customerName: "Nell",
                    potionName: "Violet Tonic",
                    targetColor: palette[4],
                    shortCopy: "Prepare one violet tonic."
                )
            )
        ]
    }

    static func makeLevel(
        id: Int,
        difficulty: Difficulty,
        rows: [[Int]],
        objective: LevelObjective = .sortAll,
        customerOrder: CustomerOrder? = nil
    ) -> Level {
        Level(
            id: id,
            difficulty: difficulty,
            filledFlasks: rows.map { row in
                Flask(colors: row.map { palette[$0] })
            },
            availableEmptyFlaskCount: GameManager.startingEmptyFlaskCount,
            hasLockedBonusFlask: id >= Level.lockedBonusIntroductionLevelID,
            objective: objective,
            customerOrder: customerOrder
        )
    }

    static func makeOrder(
        customerName: String,
        potionName: String,
        targetColor: LiquidColor,
        shortCopy: String
    ) -> CustomerOrder {
        CustomerOrder(
            customerName: customerName,
            potionName: potionName,
            targetColor: targetColor,
            rewardHerbs: 8,
            shortCopy: shortCopy
        )
    }

    static func makeGeneratedLevel(id: Int) -> Level {
        let colorCount = GameManager.defaultFilledFlaskCount
        let colors = Array(palette.prefix(colorCount))
        let validator = LevelSolvabilityValidator(maxVisitedStates: 75_000)

        for attempt in 0..<200 {
            var randomNumberGenerator = SeededRandomNumberGenerator(
                seed: generatedSeed(levelID: id, attempt: attempt)
            )
            let rows = colors
                .flatMap { color in Array(repeating: color, count: Flask.maxCapacity) }
                .shuffled(using: &randomNumberGenerator)
                .chunked(into: Flask.maxCapacity)

            guard rows.allSatisfy({ Set($0).count > 1 }) else { continue }

            let level = Level(
                id: id,
                difficulty: .medium,
                filledFlasks: rows.map { Flask(colors: $0) },
                availableEmptyFlaskCount: GameManager.startingEmptyFlaskCount,
                hasLockedBonusFlask: id >= Level.lockedBonusIntroductionLevelID
            )

            let report = validator.reportWithoutBonusFlask(level)
            if report.isSolvable {
                return level
            }
        }

        preconditionFailure("Unable to generate a solvable level for id \(id)")
    }

    static func generatedSeed(levelID: Int, attempt: Int) -> UInt64 {
        UInt64(levelID + 1) &* 0x9E3779B97F4A7C15 &+ UInt64(attempt)
    }

    static let palette: [LiquidColor] = [
        .ruby,
        .emerald,
        .honey,
        .moonBlue,
        .violet
    ]
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
