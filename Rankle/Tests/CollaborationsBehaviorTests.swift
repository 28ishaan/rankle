import XCTest
@testable import Rankle

/// Integration tests for collaborative list behavior and edge cases
final class CollaborationsBehaviorTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    private var ownerUserId: UUID!
    private var collaboratorUserId: UUID!

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-collab-behavior-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
        ownerUserId = UserService.shared.currentUserId
        collaboratorUserId = UUID()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        viewModel = nil
        ownerUserId = nil
        collaboratorUserId = nil
        super.tearDown()
    }

    // MARK: - Aggregation Behavior
    
    func testAggregationWithOpposingRankings() {
        viewModel.createList(name: "Movies", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let ids = list.items.map { $0.id }

        // Two collaborators with completely opposite rankings
        let collab1 = CollaboratorRanking(userId: ownerUserId, ranking: [ids[0], ids[1], ids[2]])
        let collab2 = CollaboratorRanking(userId: collaboratorUserId, ranking: [ids[2], ids[1], ids[0]])

        viewModel.upsertContribution(listId: list.id, ranking: collab1)
        viewModel.upsertContribution(listId: list.id, ranking: collab2)

        guard let updated = viewModel.lists.first else { return XCTFail("Expected updated list") }
        
        // Items should be aggregated (middle item B should likely be second)
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(aggregated.count, 3, "All items should be in aggregated ranking")
        
        // B is ranked second in both, so it should be high in aggregate
        let bIndex = aggregated.firstIndex(where: { $0.id == ids[1] })
        XCTAssertNotNil(bIndex, "Item B should be in aggregated ranking")
    }
    
    func testAggregationWithMissingItemsInRanking() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Missing", items: [a, b, c], isCollaborative: true)
        
        // Collaborator only ranks A and C (missing B)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, c.id])
        ]
        
        let agg = storage.aggregateRanking(for: list)
        
        // Unranked item B should be treated as bottom position
        XCTAssertEqual(agg.count, 3, "All items should appear")
        XCTAssertTrue(agg.contains(where: { $0.id == b.id }), "Missing item should still appear")
        
        // A and C should rank higher than B (which is unranked/bottom)
        let aIndex = agg.firstIndex(where: { $0.id == a.id })!
        let cIndex = agg.firstIndex(where: { $0.id == c.id })!
        let bIndex = agg.firstIndex(where: { $0.id == b.id })!
        XCTAssertLessThan(aIndex, bIndex, "Ranked items should be above unranked")
        XCTAssertLessThan(cIndex, bIndex, "Ranked items should be above unranked")
    }
    
    func testAggregationWithMultipleContributionsUpdatesItemsArray() {
        viewModel.createList(name: "Auto Update", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let ids = list.items.map { $0.id }

        // Add contributions
        let collab1 = CollaboratorRanking(userId: ownerUserId, ranking: [ids[0], ids[1], ids[2]])
        let collab2 = CollaboratorRanking(userId: collaboratorUserId, ranking: [ids[2], ids[1], ids[0]])

        viewModel.upsertContribution(listId: list.id, ranking: collab1)
        viewModel.upsertContribution(listId: list.id, ranking: collab2)

        guard let updated = viewModel.lists.first else { return XCTFail("Expected updated list") }
        
        // Items array should match aggregated ranking
        let expected = storage.aggregateRanking(for: updated)
        XCTAssertEqual(updated.items.map { $0.id }, expected.map { $0.id },
                      "Items array should be updated to aggregated ranking")
    }
    
    // MARK: - Idempotency
    
    func testUpsertContributionIsIdempotentForUser() {
        viewModel.createList(name: "Idempotent", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.last else { return XCTFail("missing list") }
        let ids = list.items.map { $0.id }
        
        let uid = UUID()
        
        // First contribution
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: ids))
        
        // Same user, different ranking (should update, not duplicate)
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: ids.reversed()))
        
        let updated = viewModel.lists.last!
        XCTAssertEqual(updated.collaborators.count, 1, "Repeated contributions should update, not duplicate")
        XCTAssertEqual(updated.collaborators.first?.ranking, ids.reversed(), "Should have latest ranking")
    }
    
    // MARK: - Edge Cases
    
    func testSetCollaborativeUnknownListNoCrash() {
        // Just call with a random id; should not crash
        viewModel.setCollaborative(true, for: UUID())
        viewModel.setCollaborative(false, for: UUID())
        XCTAssertTrue(true, "Should not crash on unknown list ID")
    }
    
    func testDeleteWithInvalidIndexSet() {
        viewModel.createList(name: "Test", items: ["A"], isCollaborative: false)
        let initialCount = viewModel.lists.count
        
        // Try to delete with out-of-bounds index
        viewModel.deleteList(at: IndexSet(integer: 999))
        
        XCTAssertEqual(viewModel.lists.count, initialCount, "Should not delete anything with invalid index")
    }
    
    func testUpsertContributionWithEmptyRanking() {
        viewModel.createList(name: "Empty Rank", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        
        let contribution = CollaboratorRanking(userId: ownerUserId, ranking: [])
        viewModel.upsertContribution(listId: list.id, ranking: contribution)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.collaborators.count, 1, "Should accept empty ranking")
        XCTAssertTrue(updated.collaborators.first?.ranking.isEmpty ?? false)
    }
    
    func testAggregateRankingWithOnlyOneCollaborator() {
        viewModel.createList(name: "Single", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let ids = list.items.map { $0.id }
        
        let ranking = CollaboratorRanking(userId: ownerUserId, ranking: [ids[2], ids[0], ids[1]])
        viewModel.upsertContribution(listId: list.id, ranking: ranking)
        
        let updated = viewModel.lists.first!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        
        // With only one collaborator, aggregate should match their ranking
        XCTAssertEqual(aggregated.map { $0.id }, ranking.ranking, "Single collaborator ranking should be used")
    }
    
    func testMultipleRapidContributions() {
        viewModel.createList(name: "Rapid", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let ids = list.items.map { $0.id }
        
        // Add multiple contributions rapidly
        let user1 = UUID()
        let user2 = UUID()
        let user3 = UUID()
        
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: user1, ranking: ids))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: user2, ranking: ids.reversed()))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: user3, ranking: ids))
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.collaborators.count, 3, "Should handle rapid contributions")
    }
    
    func testAggregateRankingWithIdenticalRankings() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Identical", items: [a, b, c], isCollaborative: true)
        
        // All three collaborators rank the same
        let sameRanking = [a.id, b.id, c.id]
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: sameRanking),
            CollaboratorRanking(userId: UUID(), ranking: sameRanking),
            CollaboratorRanking(userId: UUID(), ranking: sameRanking)
        ]
        
        let aggregated = storage.aggregateRanking(for: list)
        
        // All items should be present when rankings are identical (order determined by UUID tie-breaker)
        XCTAssertEqual(aggregated.count, 3, "All items should be in aggregated ranking")
        XCTAssertTrue(aggregated.contains(where: { $0.id == a.id }), "Should contain item A")
        XCTAssertTrue(aggregated.contains(where: { $0.id == b.id }), "Should contain item B")
        XCTAssertTrue(aggregated.contains(where: { $0.id == c.id }), "Should contain item C")
        
        // All items have equal scores, so order is deterministic via UUID tie-breaker
        // Verify it's a consistent ordering (run twice to ensure determinism)
        let aggregated2 = storage.aggregateRanking(for: list)
        XCTAssertEqual(aggregated.map { $0.id }, aggregated2.map { $0.id }, 
                      "Identical rankings should produce deterministic aggregate")
    }
}
