import Foundation

struct AddItemRankingState {
    var workingOrder: [RankleItem]
    var newQueue: [RankleItem]
    var insertionRange: Range<Int>
    var candidate: RankleItem?
    var matchup: Matchup
    var processedCount: Int
}

final class AddItemRankingViewModel: ObservableObject {
    @Published private(set) var currentMatchup: Matchup?
    @Published private(set) var isComplete: Bool = false
    @Published private(set) var insertedPosition: Int?
    @Published private(set) var processedCount: Int = 0
    @Published private(set) var totalCount: Int = 0

    private var workingOrder: [RankleItem]
    private var newQueue: [RankleItem]
    private var insertionRange: Range<Int> = 0..<0
    private var candidate: RankleItem?
    private var stateHistory: [AddItemRankingState] = []

    init(existingItems: [RankleItem], newItems: [RankleItem]) {
        self.workingOrder = existingItems
        self.newQueue = newItems
        self.totalCount = newItems.count
        self.processedCount = 0
        nextInsertion()
    }

    private func nextInsertion() {
        guard !newQueue.isEmpty else {
            completeSession()
            return
        }
        candidate = newQueue.removeFirst()
        insertionRange = 0..<workingOrder.count
        insertedPosition = nil
        promptNextComparison()
    }

    private func promptNextComparison() {
        guard let candidate else { return }
        if insertionRange.isEmpty {
            let pos = insertionRange.lowerBound
            workingOrder.insert(candidate, at: pos)
            insertedPosition = pos
            processedCount += 1
            self.candidate = nil
            nextInsertion()
            return
        }
        let mid = (insertionRange.lowerBound + insertionRange.upperBound) / 2
        let matchup = Matchup(left: candidate, right: workingOrder[mid])
        
        // Save current state before showing matchup
        let state = AddItemRankingState(
            workingOrder: workingOrder,
            newQueue: newQueue,
            insertionRange: insertionRange,
            candidate: candidate,
            matchup: matchup,
            processedCount: processedCount
        )
        stateHistory.append(state)
        
        currentMatchup = matchup
    }

    func choose(_ choice: MatchupChoice) {
        guard let current = currentMatchup else { return }
        guard candidate != nil else { return }
        let midIndex = workingOrder.firstIndex(of: current.right)!
        switch choice {
        case .left:
            insertionRange = insertionRange.lowerBound..<midIndex
        case .right:
            insertionRange = (midIndex + 1)..<insertionRange.upperBound
        }
        currentMatchup = nil
        promptNextComparison()
    }

    func goBack() {
        guard stateHistory.count > 1 else { return }
        // Remove current state
        stateHistory.removeLast()
        // Restore previous state
        let previous = stateHistory.last!
        workingOrder = previous.workingOrder
        newQueue = previous.newQueue
        insertionRange = previous.insertionRange
        candidate = previous.candidate
        processedCount = previous.processedCount
        currentMatchup = previous.matchup
    }
    
    func canGoBack() -> Bool {
        return stateHistory.count > 1
    }

    private func completeSession() {
        isComplete = true
    }

    func getUpdatedList() -> [RankleItem] {
        return workingOrder
    }
}
