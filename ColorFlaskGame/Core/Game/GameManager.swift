import SwiftUI

struct Flask: Identifiable, Equatable {
    static let maxCapacity = 4

    let id: UUID
    private(set) var colors: [Color]

    init(id: UUID = UUID(), colors: [Color] = []) {
        precondition(colors.count <= Self.maxCapacity, "Flask cannot exceed max capacity")
        self.id = id
        self.colors = colors
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
        guard !isFull else { return }
        colors.append(color)
    }

    mutating func pop() -> Color? {
        colors.popLast()
    }
}

enum PourError: LocalizedError, Equatable {
    case sameFlask
    case sourceIsEmpty
    case targetIsFull
    case colorMismatch
    case invalidFlaskIndex

    var errorDescription: String? {
        switch self {
        case .sameFlask:
            return "Cannot pour into the same flask."
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
    static let defaultFlaskCount = 6
    static let emptyFlaskCount = 1

    @Published private(set) var flasks: [Flask]

    init(flasks: [Flask]) {
        self.flasks = flasks
    }

    static func makeInitialLevel(flaskCount: Int = defaultFlaskCount) -> GameManager {
        precondition(flaskCount > emptyFlaskCount, "Level must contain at least one filled flask")

        let colorCount = flaskCount - emptyFlaskCount
        let colors = Array(levelPalette.prefix(colorCount))
        precondition(colors.count == colorCount, "Not enough colors in level palette")

        let sections = colors.flatMap { color in
            Array(repeating: color, count: Flask.maxCapacity)
        }

        var flasks = sections
            .shuffled()
            .chunked(into: Flask.maxCapacity)
            .map { Flask(colors: $0) }

        flasks.append(contentsOf: Array(repeating: Flask(), count: emptyFlaskCount))

        return GameManager(flasks: flasks)
    }

    var isRoundCompleted: Bool {
        flasks.allSatisfy(\.isSolved)
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
        .red,
        .green,
        .yellow,
        .blue,
        .orange,
        .purple,
        .pink,
        .cyan
    ]
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { startIndex in
            Array(self[startIndex..<Swift.min(startIndex + size, count)])
        }
    }
}
