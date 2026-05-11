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

final class GameManager: ObservableObject {
    static let defaultFilledFlaskCount = 5
    static let startingEmptyFlaskCount = 2
    static let bonusEmptyFlaskCount = 1
    static let defaultFlaskCount = defaultFilledFlaskCount + startingEmptyFlaskCount + bonusEmptyFlaskCount

    @Published private(set) var flasks: [Flask]

    init(flasks: [Flask]) {
        self.flasks = flasks
    }

    static func makeInitialLevel(
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

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
