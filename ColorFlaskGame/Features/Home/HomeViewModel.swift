import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published private(set) var gameManager: GameManager
    @Published private(set) var selectedFlaskIndex: Int?
    @Published private(set) var moves = 0

    private var cancellables: Set<AnyCancellable> = []

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

    func selectFlask(at index: Int) {
        guard gameManager.flasks.indices.contains(index) else { return }
        selectedFlaskIndex = selectedFlaskIndex == index ? nil : index
    }

    func startNewGame() {
        selectedFlaskIndex = nil
        moves = 0
        gameManager = .makeInitialLevel()
        bindGameManager()
        objectWillChange.send()
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
