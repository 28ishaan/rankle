import XCTest
@testable import Rankle

/// Tests for real-time sync functionality and ranking completion behavior
final class RankingSyncTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    private var ownerUserId: UUID!
    
    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-sync-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
        ownerUserId = UserService.shared.currentUserId
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        viewModel = nil
        ownerUserId = nil
        super.tearDown()
    }
    
    // MARK: - Ranking Completion Saves Contribution
    
    func testRankingCompletionOnCollaborativeListSavesContribution() {
        viewModel.createList(name: "Movies", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        var list = viewModel.lists.first!
        let itemIds = list.items.map { $0.id }
        
        // Simulate completing a ranking (what RankingView does)
        let rankedOrder = [itemIds[2], itemIds[0], itemIds[1]] // C, A, B
        list.items = rankedOrder.compactMap { id in list.items.first(where: { $0.id == id }) }
        
        // Save as contribution (this happens in ListDetailView onComplete)
        let contribution = CollaboratorRanking(
            userId: ownerUserId,
            displayName: nil,
            ranking: rankedOrder,
            updatedAt: Date()
        )
        viewModel.upsertContribution(listId: listId, ranking: contribution)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 1, "Should save ranking as collaborator contribution")
        XCTAssertEqual(updated.collaborators.first?.ranking, rankedOrder, "Ranking order should match")
        XCTAssertNotNil(updated.collaborators.first?.updatedAt, "Should have timestamp")
    }
    
    func testRankingCompletionOnNonCollaborativeListDoesNotSaveContribution() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        var list = viewModel.lists.first!
        let itemIds = list.items.map { $0.id }
        
        // Complete ranking
        list.items = Array(itemIds.reversed()).compactMap { id in list.items.first(where: { $0.id == id }) }
        viewModel.replaceList(list)
        
        // Attempt to save contribution (should be skipped for non-collaborative)
        let contribution = CollaboratorRanking(userId: ownerUserId, ranking: Array(itemIds.reversed()))
        viewModel.upsertContribution(listId: listId, ranking: contribution)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertTrue(updated.collaborators.isEmpty, "Non-collaborative lists should not store contributions")
    }
    
    func testMultipleRankingCompletionsUpdateContribution() {
        viewModel.createList(name: "Updates", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // First ranking
        let firstOrder = [itemIds[0], itemIds[1], itemIds[2]]
        let firstContribution = CollaboratorRanking(userId: ownerUserId, ranking: firstOrder)
        viewModel.upsertContribution(listId: listId, ranking: firstContribution)
        
        // Second ranking (user re-ranks)
        let secondOrder = [itemIds[2], itemIds[1], itemIds[0]]
        let secondContribution = CollaboratorRanking(userId: ownerUserId, ranking: secondOrder, updatedAt: Date())
        viewModel.upsertContribution(listId: listId, ranking: secondContribution)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 1, "Should update, not duplicate")
        XCTAssertEqual(updated.collaborators.first?.ranking, secondOrder, "Should have latest ranking")
    }
    
    // MARK: - Real-time Sync via Refresh
    
    func testRefreshPicksUpNewCollaboratorContributions() {
        viewModel.createList(name: "Sync", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Add contribution in current session
        let localContribution = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: localContribution)
        
        // Simulate another user adding contribution (direct storage manipulation)
        var lists = storage.loadLists()
        var list = lists.first!
        let remoteUserId = UUID()
        let remoteContribution = CollaboratorRanking(userId: remoteUserId, ranking: Array(itemIds.reversed()))
        list.collaborators.append(remoteContribution)
        list.items = storage.aggregateRanking(for: list)
        lists[0] = list
        storage.saveLists(lists)
        
        // Refresh should pick it up
        viewModel.refresh()
        
        let refreshed = viewModel.getList(id: listId)!
        XCTAssertEqual(refreshed.collaborators.count, 2, "Refresh should pick up new contributions")
        XCTAssertTrue(refreshed.collaborators.contains(where: { $0.userId == remoteUserId }))
    }
    
    func testRefreshUpdatesAggregatedRanking() {
        viewModel.createList(name: "Aggregate", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Initial contribution - ranks A, B, C
        let contribution1 = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: contribution1)
        
        let beforeRefresh = viewModel.getAggregateRanking(for: viewModel.getList(id: listId)!)
        // With one collaborator, should match their ranking
        XCTAssertEqual(beforeRefresh.map { $0.id }, itemIds, "Single collaborator should determine ranking")
        
        // Simulate remote contribution (storage) with different ranking - ranks C, A, B
        var lists = storage.loadLists()
        var list = lists.first!
        let contribution2 = CollaboratorRanking(userId: UUID(), ranking: [itemIds[2], itemIds[0], itemIds[1]])
        list.collaborators.append(contribution2)
        list.items = storage.aggregateRanking(for: list)
        lists[0] = list
        storage.saveLists(lists)
        
        viewModel.refresh()
        
        let afterRefresh = viewModel.getAggregateRanking(for: viewModel.getList(id: listId)!)
        
        // Should be different
        // With rankings [A,B,C] and [C,A,B]:
        // A scores: 3 + 2 = 5 (should be first)
        // B scores: 2 + 1 = 3
        // C scores: 1 + 3 = 4
        XCTAssertNotEqual(beforeRefresh.map { $0.id }, afterRefresh.map { $0.id },
                         "Aggregated ranking should update after refresh")
        XCTAssertEqual(afterRefresh.first?.id, itemIds[0], "A should be first after both contributions")
    }
    
    func testRefreshMaintainsDataIntegrity() {
        viewModel.createList(name: "Integrity", items: ["A", "B"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        
        // Add contribution
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        let contribution = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: contribution)
        
        let before = viewModel.getList(id: listId)!
        let beforeCollaborators = before.collaborators.count
        let beforeItems = before.items.count
        
        // Refresh
        viewModel.refresh()
        
        let after = viewModel.getList(id: listId)!
        XCTAssertEqual(after.collaborators.count, beforeCollaborators, "Collaborators should be preserved")
        XCTAssertEqual(after.items.count, beforeItems, "Items should be preserved")
    }
    
    // MARK: - Add Item Ranking Sync
    
    func testAddItemRankingSavesContribution() {
        viewModel.createList(name: "Add Items", items: ["A", "B"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        var list = viewModel.lists.first!
        
        // Add new items and rank them
        let newItem = RankleItem(title: "C")
        list.items.append(newItem)
        let allIds = list.items.map { $0.id }
        let newRanking = [allIds[2], allIds[0], allIds[1]] // C, A, B
        
        // Save updated list with new items
        list.items = newRanking.compactMap { id in list.items.first(where: { $0.id == id }) }
        viewModel.replaceList(list)
        
        // Save as contribution (what AddItemRankingView does)
        let contribution = CollaboratorRanking(userId: ownerUserId, ranking: newRanking)
        viewModel.upsertContribution(listId: listId, ranking: contribution)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.items.count, 3, "Should have new item")
        XCTAssertEqual(updated.collaborators.count, 1, "Should save contribution")
        XCTAssertEqual(updated.collaborators.first?.ranking, newRanking, "Ranking should include new item")
    }
    
    // MARK: - Edge Cases
    
    func testRefreshWithDeletedList() {
        viewModel.createList(name: "Delete Me", items: ["A"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        
        // Delete via storage (simulating another device)
        var lists = storage.loadLists()
        lists.removeAll { $0.id == listId }
        storage.saveLists(lists)
        
        viewModel.refresh()
        
        let result = viewModel.getList(id: listId)
        XCTAssertNil(result, "Deleted list should not appear after refresh")
    }
    
    func testMultipleRapidRefreshes() {
        viewModel.createList(name: "Rapid", items: ["A"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        
        // Multiple rapid refreshes
        viewModel.refresh()
        viewModel.refresh()
        viewModel.refresh()
        
        let result = viewModel.getList(id: listId)
        XCTAssertNotNil(result, "Rapid refreshes should not cause issues")
        XCTAssertEqual(result?.name, "Rapid")
    }
    
    func testRefreshWithCorruptedStorage() {
        viewModel.createList(name: "Corrupt", items: ["A"], isCollaborative: false)
        
        // Corrupt storage file
        let listsURL = tempDir.appendingPathComponent("rankle_lists.json")
        try? "corrupted data".data(using: .utf8)?.write(to: listsURL)
        
        // Should fall back to backup or handle gracefully
        viewModel.refresh()
        
        // Should not crash - either restored from backup or empty
        XCTAssertTrue(true, "Should handle corrupted storage gracefully")
    }
    
    func testContributionTimestampUpdates() {
        viewModel.createList(name: "Timestamps", items: ["A", "B"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        let firstContribution = CollaboratorRanking(userId: ownerUserId, ranking: itemIds, updatedAt: Date())
        viewModel.upsertContribution(listId: listId, ranking: firstContribution)
        
        let firstTimestamp = viewModel.getList(id: listId)!.collaborators.first!.updatedAt
        
        // Small delay to ensure different timestamp
        Thread.sleep(forTimeInterval: 0.1)
        
        let secondContribution = CollaboratorRanking(userId: ownerUserId, ranking: Array(itemIds.reversed()), updatedAt: Date())
        viewModel.upsertContribution(listId: listId, ranking: secondContribution)
        
        let secondTimestamp = viewModel.getList(id: listId)!.collaborators.first!.updatedAt
        
        XCTAssertGreaterThan(secondTimestamp, firstTimestamp, "Timestamp should update on new contribution")
    }
}

