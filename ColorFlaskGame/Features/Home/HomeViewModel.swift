import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    @Published private(set) var completedFlasks = 3
    @Published private(set) var totalFlasks = 6
    @Published private(set) var moves = 18

    var progress: Double {
        guard totalFlasks > 0 else { return 0 }
        return Double(completedFlasks) / Double(totalFlasks)
    }

    func startNewGame() {
        completedFlasks = 0
        moves = 0
    }
}
