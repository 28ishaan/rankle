import XCTest
@testable import Rankle

final class CollaborativeListTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    private var ownerUserId: UUID!
    private var collaboratorUserId: UUID!

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-collab-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
        
        // Capture current user IDs for testing
        ownerUserId = UserService.shared.currentUserId
        collaboratorUserId = UUID() // Different user
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

    // MARK: - Ownership and Permissions Tests
    
    func testOwnerCanDeleteCollaborativeList() {
        viewModel.createList(name: "My List", items: ["A", "B"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let initialCount = viewModel.lists.count
        
        viewModel.deleteList(at: IndexSet(integer: 0))
        
        XCTAssertEqual(viewModel.lists.count, initialCount - 1, "Owner should be able to delete their collaborative list")
        XCTAssertNil(viewModel.getList(id: listId), "List should be deleted")
    }
    
    func testNonOwnerCannotDeleteCollaborativeList() {
        viewModel.createList(name: "Shared List", items: ["A", "B"], isCollaborative: true)
        var list = viewModel.lists.first!
        list.ownerId = collaboratorUserId // Make someone else the owner
        viewModel.replaceList(list)
        
        let initialCount = viewModel.lists.count
        let listId = list.id
        
        viewModel.deleteList(at: IndexSet(integer: 0))
        
        XCTAssertEqual(viewModel.lists.count, initialCount, "Non-owner should not be able to delete collaborative list")
        XCTAssertNotNil(viewModel.getList(id: listId), "List should still exist")
    }
    
    func testNonOwnerCanDeleteNonCollaborativeList() {
        viewModel.createList(name: "Regular List", items: ["A", "B"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.ownerId = collaboratorUserId // Different owner, but not collaborative
        viewModel.replaceList(list)
        
        let initialCount = viewModel.lists.count
        
        viewModel.deleteList(at: IndexSet(integer: 0))
        
        XCTAssertEqual(viewModel.lists.count, initialCount - 1, "Non-collaborative lists can be deleted by anyone")
    }
    
    func testCanDeleteListHelperFunction() {
        viewModel.createList(name: "Owned", items: ["A"], isCollaborative: true)
        let ownedList = viewModel.lists.first!
        
        viewModel.createList(name: "Shared", items: ["B"], isCollaborative: true)
        var sharedList = viewModel.lists.last!
        sharedList.ownerId = collaboratorUserId
        viewModel.replaceList(sharedList)
        let updatedSharedList = viewModel.lists.last!
        
        XCTAssertTrue(viewModel.canDeleteList(ownedList), "Owner should be able to delete their list")
        XCTAssertFalse(viewModel.canDeleteList(updatedSharedList), "Non-owner should not be able to delete collaborative list")
    }
    
    func testOwnerCanToggleCollaborativeOn() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        
        viewModel.setCollaborative(true, for: listId)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertTrue(updated.isCollaborative, "Owner should be able to enable collaboration")
        XCTAssertEqual(updated.ownerId, ownerUserId, "Owner should remain the same")
    }
    
    func testOwnerCanToggleCollaborativeOff() {
        viewModel.createList(name: "Collaborative", items: ["A", "B"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        
        // Add collaborators first
        let ranking = CollaboratorRanking(userId: collaboratorUserId, ranking: [])
        viewModel.upsertContribution(listId: listId, ranking: ranking)
        
        viewModel.setCollaborative(false, for: listId)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertFalse(updated.isCollaborative, "Owner should be able to disable collaboration")
        XCTAssertTrue(updated.collaborators.isEmpty, "Disabling should clear collaborators")
    }
    
    func testNonOwnerCannotToggleCollaborativeOn() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.ownerId = collaboratorUserId
        viewModel.replaceList(list)
        let listId = list.id
        
        viewModel.setCollaborative(true, for: listId)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertFalse(updated.isCollaborative, "Non-owner should not be able to enable collaboration")
    }
    
    func testNonOwnerCannotToggleCollaborativeOff() {
        viewModel.createList(name: "Shared", items: ["A", "B"], isCollaborative: true)
        var list = viewModel.lists.first!
        list.ownerId = collaboratorUserId
        viewModel.replaceList(list)
        let listId = list.id
        
        viewModel.setCollaborative(false, for: listId)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertTrue(updated.isCollaborative, "Non-owner should not be able to disable collaboration")
    }
    
    // MARK: - Collaborator Contribution Tests
    
    func testRankingCompletionSavesAsCollaboratorContribution() {
        viewModel.createList(name: "Movies", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        var list = viewModel.lists.first!
        let itemIds = list.items.map { $0.id }
        
        // Simulate ranking completion - items should be in some order
        let rankedOrder = [itemIds[2], itemIds[0], itemIds[1]] // Different order
        list.items = rankedOrder.compactMap { id in list.items.first(where: { $0.id == id }) }
        
        // Save as collaborator contribution (this is what happens when ranking completes)
        let contribution = CollaboratorRanking(
            userId: ownerUserId,
            displayName: nil,
            ranking: rankedOrder,
            updatedAt: Date()
        )
        viewModel.upsertContribution(listId: listId, ranking: contribution)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 1, "Should have one collaborator contribution")
        XCTAssertEqual(updated.collaborators.first?.userId, ownerUserId, "Contribution should be from current user")
        XCTAssertEqual(updated.collaborators.first?.ranking, rankedOrder, "Ranking should match")
    }
    
    func testUpsertContributionUpdatesExistingUserRanking() {
        viewModel.createList(name: "Foods", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // First contribution
        let firstRanking = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: firstRanking)
        
        // Second contribution from same user (should update, not duplicate)
        let secondRanking = CollaboratorRanking(userId: ownerUserId, ranking: Array(itemIds.reversed()))
        viewModel.upsertContribution(listId: listId, ranking: secondRanking)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 1, "Should update existing contribution, not create duplicate")
        XCTAssertEqual(updated.collaborators.first?.ranking, Array(itemIds.reversed()), "Should have latest ranking")
    }
    
    func testMultipleCollaboratorsCanContribute() {
        viewModel.createList(name: "Books", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        let user1Ranking = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        let user2Ranking = CollaboratorRanking(userId: collaboratorUserId, ranking: Array(itemIds.reversed()))
        
        viewModel.upsertContribution(listId: listId, ranking: user1Ranking)
        viewModel.upsertContribution(listId: listId, ranking: user2Ranking)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 2, "Should have contributions from both users")
        XCTAssertTrue(updated.collaborators.contains(where: { $0.userId == ownerUserId }))
        XCTAssertTrue(updated.collaborators.contains(where: { $0.userId == collaboratorUserId }))
    }
    
    func testUpsertContributionUpdatesAggregatedRanking() {
        viewModel.createList(name: "Songs", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Add first collaborator - ranks A, B, C
        let ranking1 = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: ranking1)
        
        let afterFirst = viewModel.getList(id: listId)!
        let initialAggregated = viewModel.getAggregateRanking(for: afterFirst)
        
        // With only one collaborator, aggregated should match their ranking
        XCTAssertEqual(initialAggregated.map { $0.id }, itemIds, "Single collaborator should determine ranking")
        
        // Add second collaborator with different ranking - ranks C, A, B (not fully reversed to ensure difference)
        let ranking2 = CollaboratorRanking(userId: collaboratorUserId, ranking: [itemIds[2], itemIds[0], itemIds[1]])
        viewModel.upsertContribution(listId: listId, ranking: ranking2)
        
        let afterSecond = viewModel.getList(id: listId)!
        let finalAggregated = viewModel.getAggregateRanking(for: afterSecond)
        
        // Aggregated ranking should be different after second contribution
        // With rankings [A,B,C] and [C,A,B]:
        // A scores: 3 (pos 0) + 2 (pos 1) = 5
        // B scores: 2 (pos 1) + 1 (pos 2) = 3
        // C scores: 1 (pos 2) + 3 (pos 0) = 4
        // So A should be first
        XCTAssertNotEqual(initialAggregated.map { $0.id }, finalAggregated.map { $0.id }, 
                         "Aggregated ranking should update when new contribution is added")
        XCTAssertEqual(finalAggregated.first?.id, itemIds[0], "A should be first with rankings [A,B,C] and [C,A,B]")
    }
    
    func testAggregatedRankingReflectsCollaboratorContributions() {
        viewModel.createList(name: "Shows", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // All three users rank B first
        let ranking1 = CollaboratorRanking(userId: ownerUserId, ranking: [itemIds[1], itemIds[0], itemIds[2]])
        let ranking2 = CollaboratorRanking(userId: collaboratorUserId, ranking: [itemIds[1], itemIds[2], itemIds[0]])
        let ranking3 = CollaboratorRanking(userId: UUID(), ranking: [itemIds[1], itemIds[0], itemIds[2]])
        
        viewModel.upsertContribution(listId: listId, ranking: ranking1)
        viewModel.upsertContribution(listId: listId, ranking: ranking2)
        viewModel.upsertContribution(listId: listId, ranking: ranking3)
        
        let updated = viewModel.getList(id: listId)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        
        // B should be first in aggregated ranking
        XCTAssertEqual(aggregated.first?.id, itemIds[1], "Item ranked first by all should be aggregated first")
    }
    
    // MARK: - Refresh and Real-time Sync Tests
    
    func testRefreshReloadsListsFromStorage() {
        viewModel.createList(name: "Initial", items: ["A"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        
        // Modify storage directly (simulating another user/device)
        var lists = storage.loadLists()
        lists[0].name = "Modified"
        storage.saveLists(lists)
        
        // Refresh should pick up the change
        viewModel.refresh()
        
        let refreshed = viewModel.getList(id: listId)!
        XCTAssertEqual(refreshed.name, "Modified", "Refresh should reload from storage")
    }
    
    func testRefreshUpdatesCollaborativeRankings() {
        viewModel.createList(name: "Sync Test", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Add contribution in current view model
        let ranking = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: ranking)
        
        // Simulate another contribution from storage (another user)
        var lists = storage.loadLists()
        var list = lists.first!
        let newRanking = CollaboratorRanking(userId: collaboratorUserId, ranking: Array(itemIds.reversed()))
        list.collaborators.append(newRanking)
        // Recalculate aggregated
        list.items = storage.aggregateRanking(for: list)
        lists[0] = list
        storage.saveLists(lists)
        
        // Refresh should pick up new collaborator
        viewModel.refresh()
        
        let refreshed = viewModel.getList(id: listId)!
        XCTAssertEqual(refreshed.collaborators.count, 2, "Refresh should pick up new collaborator contributions")
    }
    
    func testGetListReturnsFreshData() {
        viewModel.createList(name: "Fresh Test", items: ["A"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        
        // Modify via view model
        viewModel.renameList(listId, newName: "Renamed")
        
        // getList should return the updated version
        let fresh = viewModel.getList(id: listId)!
        XCTAssertEqual(fresh.name, "Renamed", "getList should return current state")
    }
    
    func testGetAggregateRankingUsesFreshData() {
        viewModel.createList(name: "Aggregate Test", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Add first contribution - ranks A, B, C
        let ranking1 = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: ranking1)
        
        let list1 = viewModel.getList(id: listId)!
        let aggregated1 = viewModel.getAggregateRanking(for: list1)
        
        // With one collaborator, should match their ranking
        XCTAssertEqual(aggregated1.map { $0.id }, itemIds, "Single collaborator should determine ranking")
        
        // Add second contribution with different ranking - ranks C, A, B
        let ranking2 = CollaboratorRanking(userId: collaboratorUserId, ranking: [itemIds[2], itemIds[0], itemIds[1]])
        viewModel.upsertContribution(listId: listId, ranking: ranking2)
        
        let list2 = viewModel.getList(id: listId)!
        let aggregated2 = viewModel.getAggregateRanking(for: list2)
        
        // Aggregated ranking should be different
        // With rankings [A,B,C] and [C,A,B]:
        // A scores: 3 + 2 = 5 (should be first)
        // B scores: 2 + 1 = 3
        // C scores: 1 + 3 = 4
        XCTAssertNotEqual(aggregated1.map { $0.id }, aggregated2.map { $0.id },
                         "Aggregate ranking should reflect latest contributions")
        XCTAssertEqual(aggregated2.first?.id, itemIds[0], "A should be first after both contributions")
    }
    
    // MARK: - Edge Cases
    
    func testNonCollaborativeListDoesNotSaveContributions() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        let ranking = CollaboratorRanking(userId: ownerUserId, ranking: itemIds)
        viewModel.upsertContribution(listId: listId, ranking: ranking)
        
        let updated = viewModel.getList(id: listId)!
        XCTAssertTrue(updated.collaborators.isEmpty, "Non-collaborative lists should not store contributions")
    }
    
    func testUpsertContributionForNonExistentListDoesNothing() {
        let fakeListId = UUID()
        let ranking = CollaboratorRanking(userId: ownerUserId, ranking: [])
        
        // Should not crash
        viewModel.upsertContribution(listId: fakeListId, ranking: ranking)
        
        XCTAssertTrue(viewModel.lists.isEmpty, "Should not create new list")
    }
    
    func testDeleteWithMultipleListsOnlyDeletesAllowed() {
        // Create owned collaborative list
        viewModel.createList(name: "Owned", items: ["A"], isCollaborative: true)
        
        // Create non-owned collaborative list
        viewModel.createList(name: "Shared", items: ["B"], isCollaborative: true)
        var shared = viewModel.lists.last!
        shared.ownerId = collaboratorUserId
        viewModel.replaceList(shared)
        
        // Create regular list
        viewModel.createList(name: "Regular", items: ["C"], isCollaborative: false)
        
        let initialCount = viewModel.lists.count
        
        // Try to delete all three (indices 0, 1, 2)
        viewModel.deleteList(at: IndexSet([0, 1, 2]))
        
        // Should delete owned and regular, but not shared
        XCTAssertEqual(viewModel.lists.count, initialCount - 2, "Should delete allowed lists only")
        XCTAssertEqual(viewModel.lists.first?.name, "Shared", "Shared list should remain")
    }
    
    func testAggregateRankingWithMissingItems() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Missing", items: [a, b, c], isCollaborative: true)
        
        // Collaborator only ranks A and C, missing B
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, c.id])
        ]
        
        let aggregated = storage.aggregateRanking(for: list)
        
        XCTAssertEqual(aggregated.count, 3, "All items should be in aggregated ranking")
        XCTAssertTrue(aggregated.contains(where: { $0.id == b.id }), "Missing item should still appear")
    }
    
    func testAggregateRankingWithEmptyCollaborators() {
        let list = RankleList(name: "Empty", items: [
            RankleItem(title: "A"),
            RankleItem(title: "B")
        ], isCollaborative: true)
        
        let aggregated = storage.aggregateRanking(for: list)
        
        // Should return original order when no collaborators
        XCTAssertEqual(aggregated.count, 2)
        XCTAssertEqual(aggregated.map { $0.title }, list.items.map { $0.title })
    }
    
    func testRefreshWithNoChanges() {
        viewModel.createList(name: "Stable", items: ["A"], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        let originalName = viewModel.getList(id: listId)!.name
        
        viewModel.refresh()
        
        let afterRefresh = viewModel.getList(id: listId)!
        XCTAssertEqual(afterRefresh.name, originalName, "Refresh should maintain data when nothing changed")
    }
    
    func testGetListReturnsNilForNonExistentId() {
        let fakeId = UUID()
        let result = viewModel.getList(id: fakeId)
        
        XCTAssertNil(result, "Should return nil for non-existent list ID")
    }
    
    func testCollaborativeListItemsUpdatedAfterContribution() {
        viewModel.createList(name: "Auto Update", items: ["A", "B", "C"], isCollaborative: true)
        let listId = viewModel.lists.first!.id
        let itemIds = viewModel.lists.first!.items.map { $0.id }
        
        // Add contribution
        let ranking = CollaboratorRanking(userId: ownerUserId, ranking: Array(itemIds.reversed()))
        viewModel.upsertContribution(listId: listId, ranking: ranking)
        
        // Items array should be updated to aggregated ranking
        let afterContribution = viewModel.getList(id: listId)!
        let aggregated = viewModel.getAggregateRanking(for: afterContribution)
        
        XCTAssertEqual(afterContribution.items.map { $0.id }, aggregated.map { $0.id },
                      "List items should match aggregated ranking after contribution")
    }
}
