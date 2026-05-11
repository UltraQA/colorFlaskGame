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

final class GameManager: ObservableObject {
    @Published private(set) var flasks: [Flask]

    init(flasks: [Flask]) {
        self.flasks = flasks
    }

    static func makeInitialLevel() -> GameManager {
        GameManager(
            flasks: [
                Flask(colors: [.red, .green, .yellow, .red]),
                Flask(colors: [.green, .yellow, .red, .green]),
                Flask(colors: [.yellow, .red, .green, .yellow]),
                Flask(colors: [.red, .yellow, .green, .red]),
                Flask(colors: [.green, .red, .yellow, .green]),
                Flask(colors: [])
            ]
        )
    }

    var isRoundCompleted: Bool {
        flasks.allSatisfy(\.isSolved)
    }

    @discardableResult
    func pour(from sourceIndex: Int, to targetIndex: Int) -> Result<Int, PourError> {
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

        for _ in 0..<amountToPour {
            _ = flasks[sourceIndex].pop()
            flasks[targetIndex].push(sourceTopColor)
        }

        return .success(amountToPour)
    }
}
