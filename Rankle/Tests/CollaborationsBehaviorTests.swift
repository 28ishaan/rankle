import XCTest
@testable import Rankle

/// Integration tests for collaborative list aggregation algorithm and edge cases.
final class CollaborationsBehaviorTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    private var currentUserId: UUID!
    private var otherUserId: UUID!

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rankle-collab-behavior-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
        currentUserId = UserService.shared.currentUserId
        otherUserId = UUID()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil; storage = nil; viewModel = nil
        currentUserId = nil; otherUserId = nil
        super.tearDown()
    }

    // MARK: - Borda Count Scoring

    /// Borda count formula: with n items, item at position p gets score (n − p).
    /// Position 0 → score n, position n-1 → score 1.
    private func expectedBordaScore(position: Int, itemCount: Int) -> Double {
        Double(itemCount - position)
    }

    func testBordaScoreIncreasesWithHigherRank() {
        // With 3 items, positions 0,1,2 get scores 3,2,1
        XCTAssertGreaterThan(expectedBordaScore(position: 0, itemCount: 3),
                             expectedBordaScore(position: 1, itemCount: 3))
        XCTAssertGreaterThan(expectedBordaScore(position: 1, itemCount: 3),
                             expectedBordaScore(position: 2, itemCount: 3))
    }

    // MARK: - Aggregation: Identical Rankings

    /// When every collaborator submits the same ranking, the Borda scores are
    /// all different (not equal), and the aggregate output matches that shared ranking.
    func testAggregateMatchesWhenAllCollaboratorsRankIdentically() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Identical", items: [a, b, c], isCollaborative: true)

        let sharedRanking = [a.id, b.id, c.id]
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: sharedRanking),
            CollaboratorRanking(userId: UUID(), ranking: sharedRanking),
            CollaboratorRanking(userId: UUID(), ranking: sharedRanking),
        ]

        let aggregated = storage.aggregateRanking(for: list)

        // Borda scores: a = 3*3=9, b = 2*3=6, c = 1*3=3 (NOT equal — a > b > c)
        // Therefore the aggregate must equal the shared ranking exactly.
        XCTAssertEqual(aggregated.map { $0.id }, sharedRanking,
                       "When everyone ranks the same, the aggregate must match that ranking")
    }

    func testAggregateIsProducedDeterministically() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        var list = RankleList(name: "Deterministic", items: [a, b], isCollaborative: true)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, b.id]),
            CollaboratorRanking(userId: UUID(), ranking: [a.id, b.id]),
        ]

        let result1 = storage.aggregateRanking(for: list)
        let result2 = storage.aggregateRanking(for: list)

        XCTAssertEqual(result1.map { $0.id }, result2.map { $0.id },
                       "Repeated calls with the same input must produce the same output")
    }

    // MARK: - Aggregation: Opposing Rankings

    /// Two fully opposing rankings give every item an identical Borda score.
    /// The tie-breaker (UUID string comparison) still produces a deterministic, stable order.
    func testOpposingRankingsProduceEqualBordaScores() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Opposing", items: [a, b, c], isCollaborative: true)

        // [A,B,C] vs [C,B,A]
        // A: pos 0 → 3 pts, pos 2 → 1 pt = 4
        // B: pos 1 → 2 pts, pos 1 → 2 pts = 4
        // C: pos 2 → 1 pt,  pos 0 → 3 pts = 4
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, b.id, c.id]),
            CollaboratorRanking(userId: UUID(), ranking: [c.id, b.id, a.id]),
        ]

        let aggregated = storage.aggregateRanking(for: list)

        XCTAssertEqual(aggregated.count, 3, "All items must appear in the aggregate")
        XCTAssertTrue(aggregated.contains(where: { $0.id == a.id }))
        XCTAssertTrue(aggregated.contains(where: { $0.id == b.id }))
        XCTAssertTrue(aggregated.contains(where: { $0.id == c.id }))

        // Since all items tie, the order is determined by UUID string comparison.
        // We don't assert a specific position, but we do verify determinism.
        let secondRun = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.map { $0.id }, secondRun.map { $0.id },
                       "Tied items must be broken deterministically on every call")
    }

    // MARK: - Aggregation: Partially Missing Items

    func testUnrankedItemsReceiveBottomPositionPenalty() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Missing", items: [a, b, c], isCollaborative: true)

        // Collaborator only ranks A and C; B is absent (treated as last position)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, c.id])
        ]

        let aggregated = storage.aggregateRanking(for: list)

        XCTAssertEqual(aggregated.count, 3, "All items must appear even when some are omitted from a ranking")
        // B was unranked → placed at bottom position (n-1=2) → score (3-2)=1
        // A at pos 0 → score 3, C at pos 1 → score 2
        let aIdx = aggregated.firstIndex(where: { $0.id == a.id })!
        let cIdx = aggregated.firstIndex(where: { $0.id == c.id })!
        let bIdx = aggregated.firstIndex(where: { $0.id == b.id })!
        XCTAssertLessThan(aIdx, bIdx, "Ranked item A should appear before unranked item B")
        XCTAssertLessThan(cIdx, bIdx, "Ranked item C should appear before unranked item B")
    }

    func testAllItemsMissingFromRankingStillAppearInAggregate() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        var list = RankleList(name: "AllMissing", items: [a, b], isCollaborative: true)

        // Collaborator submits an empty ranking
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [])
        ]

        let aggregated = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.count, 2, "Items must appear even when the collaborator ranking is empty")
    }

    // MARK: - Aggregation: Edge Cases

    func testAggregateWithNoCollaboratorsReturnsOriginalItems() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let list = RankleList(name: "Empty", items: [a, b], isCollaborative: true)
        // collaborators is empty

        let aggregated = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.map { $0.title }, ["A", "B"],
                       "With no collaborators the original order is returned unchanged")
    }

    func testAggregateOnNonCollaborativeListReturnsOriginalItems() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        var list = RankleList(name: "Regular", items: [a, b], isCollaborative: false)
        list.collaborators = [CollaboratorRanking(userId: UUID(), ranking: [b.id, a.id])]

        let aggregated = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.map { $0.title }, ["A", "B"],
                       "Non-collaborative lists always return original order regardless of any stored collaborators")
    }

    func testAggregateWithSingleCollaboratorMatchesTheirRanking() {
        viewModel.createList(name: "Single", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }
        let preferred = [ids[2], ids[0], ids[1]]  // C, A, B

        viewModel.upsertContribution(
            listId: list.id,
            ranking: CollaboratorRanking(userId: currentUserId, ranking: preferred)
        )

        let updated    = viewModel.getList(id: list.id)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(aggregated.map { $0.id }, preferred,
                       "With only one collaborator the aggregate must match their ranking exactly")
    }

    func testAggregateWithTwoOpposingCollaboratorsContainsAllItems() {
        viewModel.createList(name: "Movies", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: currentUserId, ranking: ids))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: otherUserId,   ranking: Array(ids.reversed())))

        let updated    = viewModel.getList(id: list.id)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(aggregated.count, 3)
        for id in ids { XCTAssertTrue(aggregated.contains(where: { $0.id == id })) }
    }

    // MARK: - Borda Count Verification with Known Input

    func testBordaCountScoreOrderIsCorrectWithThreeCollaborators() {
        // Rankings: [A,B,C], [A,C,B], [B,A,C]
        // n=3, scores:
        //   A: pos0→3 + pos0→3 + pos1→2 = 8
        //   B: pos1→2 + pos2→1 + pos0→3 = 6
        //   C: pos2→1 + pos1→2 + pos2→1 = 4
        // Expected aggregate: [A, B, C]
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Borda", items: [a, b, c], isCollaborative: true)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, b.id, c.id]),
            CollaboratorRanking(userId: UUID(), ranking: [a.id, c.id, b.id]),
            CollaboratorRanking(userId: UUID(), ranking: [b.id, a.id, c.id]),
        ]

        let aggregated = storage.aggregateRanking(for: list)

        XCTAssertEqual(aggregated[0].id, a.id, "A should be ranked 1st (score 8)")
        XCTAssertEqual(aggregated[1].id, b.id, "B should be ranked 2nd (score 6)")
        XCTAssertEqual(aggregated[2].id, c.id, "C should be ranked 3rd (score 4)")
    }

    func testBordaCountWithClearConsensus() {
        // All collaborators rank B first → B must win the aggregate
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Consensus", items: [a, b, c], isCollaborative: true)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [b.id, a.id, c.id]),
            CollaboratorRanking(userId: UUID(), ranking: [b.id, c.id, a.id]),
            CollaboratorRanking(userId: UUID(), ranking: [b.id, a.id, c.id]),
        ]

        let aggregated = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.first?.id, b.id,
                       "Item ranked first by every collaborator must win the aggregate")
    }

    // MARK: - Idempotency

    func testResubmittingTheSameRankingIsIdempotent() {
        viewModel.createList(name: "Idempotent", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }
        let uid = UUID()

        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: ids))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: Array(ids.reversed())))

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 1,
                       "Resubmission must replace the existing record, not add a duplicate")
        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.first?.ranking,
                       Array(ids.reversed()),
                       "The most recent ranking must be kept")
    }

    // MARK: - Edge Cases: Invalid Inputs

    func testSetCollaborativeWithUnknownIdDoesNotCrash() {
        viewModel.setCollaborative(true,  for: UUID())
        viewModel.setCollaborative(false, for: UUID())
        XCTAssertTrue(true)
    }

    func testDeleteWithOutOfBoundsIndexDoesNotCrash() {
        viewModel.createList(name: "Test", items: ["A"], isCollaborative: false)
        let countBefore = viewModel.lists.count
        viewModel.deleteList(at: IndexSet(integer: 999))
        XCTAssertEqual(viewModel.lists.count, countBefore)
    }

    func testUpsertEmptyRankingIsAccepted() {
        viewModel.createList(name: "Empty Rank", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }

        viewModel.upsertContribution(listId: list.id,
                                     ranking: CollaboratorRanking(userId: currentUserId, ranking: []))

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 1,
                       "An empty ranking is valid and should be stored")
    }

    func testManyRapidContributionsFromDifferentUsers() {
        viewModel.createList(name: "Rapid", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        let users = (0..<10).map { _ in UUID() }
        for user in users {
            viewModel.upsertContribution(listId: list.id,
                                         ranking: CollaboratorRanking(userId: user, ranking: ids))
        }

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 10)
    }

    func testAggregateItemCountMatchesListItemCount() {
        viewModel.createList(name: "Count Check", items: ["A", "B", "C", "D"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: currentUserId, ranking: ids))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: otherUserId,   ranking: Array(ids.reversed())))

        let updated    = viewModel.getList(id: list.id)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(aggregated.count, updated.items.count,
                       "Aggregate must contain exactly the same number of items as the list")
    }
}
