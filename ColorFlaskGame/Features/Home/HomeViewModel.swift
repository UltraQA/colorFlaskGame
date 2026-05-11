import SwiftUI
import Combine

struct PourAnimation: Identifiable, Equatable {
    let id = UUID()
    let sourceIndex: Int
    let targetIndex: Int
    let color: Color
}

final class HomeViewModel: ObservableObject {
    @Published private(set) var gameManager: GameManager
    @Published private(set) var selectedFlaskIndex: Int?
    @Published private(set) var pourAnimation: PourAnimation?
    @Published private(set) var moves = 0

    private var cancellables: Set<AnyCancellable> = []
    private let pourAnimationDuration: TimeInterval = 0.55

    init(gameManager: GameManager = .makeInitialLevel()) {
        self.gameManager = gameManager
        bindGameManager()
    }

    var progress: Double {
        guard !gameManager.flasks.isEmpty else { return 0 }
        let solvedCount = gameManager.flasks.filter(\.isSolved).count
        return Double(solvedCount) / Double(gameManager.flasks.count)
    }

    var completedFlasks: Int {
        gameManager.flasks.filter(\.isSolved).count
    }

    var totalFlasks: Int {
        gameManager.flasks.count
    }

    func handleFlaskTap(at index: Int) {
        guard gameManager.flasks.indices.contains(index), pourAnimation == nil else { return }

        guard let sourceIndex = selectedFlaskIndex else {
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? nil : index
            return
        }

        guard sourceIndex != index else {
            selectedFlaskIndex = nil
            return
        }

        switch gameManager.pourPlan(from: sourceIndex, to: index) {
        case let .success(plan):
            animatePour(plan)
        case .failure:
            selectedFlaskIndex = gameManager.flasks[index].isEmpty ? sourceIndex : index
        }
    }

    func startNewGame() {
        selectedFlaskIndex = nil
        pourAnimation = nil
        moves = 0
        gameManager = .makeInitialLevel()
        bindGameManager()
        objectWillChange.send()
    }

    private func animatePour(_ plan: PourPlan) {
        selectedFlaskIndex = nil
        pourAnimation = PourAnimation(
            sourceIndex: plan.sourceIndex,
            targetIndex: plan.targetIndex,
            color: plan.color
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + pourAnimationDuration) { [weak self] in
            guard let self else { return }

            withAnimation(.snappy(duration: 0.25)) {
                if case .success = self.gameManager.pour(from: plan.sourceIndex, to: plan.targetIndex) {
                    self.moves += 1
                }
                self.pourAnimation = nil
            }
        }
    }

    private func bindGameManager() {
        cancellables.removeAll()

        gameManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
