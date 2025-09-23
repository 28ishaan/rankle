import Foundation

final class RankingViewModel: ObservableObject {
    @Published private(set) var list: RankleList
    @Published private(set) var currentMatchup: Matchup?
    @Published private(set) var isComplete: Bool = false

    private var workingOrder: [RankleItem] = []
    private var newItemQueue: [RankleItem] = []
    private var insertionRange: Range<Int> = 0..<0
    private var candidate: RankleItem?

    init(list: RankleList) {
        self.list = list
        self.workingOrder = list.items
        self.isComplete = workingOrder.count <= 1
        if !isComplete {
            startPairwiseSort()
        }
    }

    func startPairwiseSort() {
        // If list is unranked, perform a simple pairwise build using insertion
        guard workingOrder.count > 1 else { isComplete = true; return }
        // Use first item as seed and insert others one by one
        let seed = workingOrder.removeFirst()
        workingOrder = [seed]
        newItemQueue = workingOrder.isEmpty ? [] : Array(list.items.dropFirst())
        nextInsertion()
    }

    private func nextInsertion() {
        guard !newItemQueue.isEmpty else {
            completeSession()
            return
        }
        candidate = newItemQueue.removeFirst()
        insertionRange = 0..<workingOrder.count
        promptNextComparison()
    }

    private func promptNextComparison() {
        guard let candidate else { return }
        if insertionRange.isEmpty {
            workingOrder.insert(candidate, at: insertionRange.lowerBound)
            self.candidate = nil
            nextInsertion()
            return
        }
        let mid = (insertionRange.lowerBound + insertionRange.upperBound) / 2
        currentMatchup = Matchup(left: candidate, right: workingOrder[mid])
    }

    func choose(_ choice: MatchupChoice) {
        guard let current = currentMatchup else { return }
        guard candidate != nil else { return }
        let midIndex = workingOrder.firstIndex(of: current.right)!
        switch choice {
        case .left:
            // Candidate preferred over mid -> search left half (higher rank)
            insertionRange = insertionRange.lowerBound..<midIndex
        case .right:
            // Mid preferred -> search right half (lower rank)
            insertionRange = (midIndex + 1)..<insertionRange.upperBound
        }
        currentMatchup = nil
        promptNextComparison()
    }

    private func completeSession() {
        isComplete = true
        list.items = workingOrder
    }
}
