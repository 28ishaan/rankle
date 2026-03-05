import XCTest
@testable import Rankle

final class CollaborativeListTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    private var currentUserId: UUID!
    private var otherUserId: UUID!

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rankle-collab-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
        currentUserId = UserService.shared.currentUserId
        otherUserId = UUID() // Represents a different user
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil; storage = nil; viewModel = nil
        currentUserId = nil; otherUserId = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Create a collaborative list owned by `otherUserId` to simulate a list shared with the current user.
    private func makeSharedList(name: String = "Shared", items: [String] = ["A", "B"]) -> RankleList {
        var list = RankleList(
            name: name,
            items: items.map { RankleItem(title: $0) },
            isCollaborative: true
        )
        list.ownerId = otherUserId
        return list
    }

    // MARK: - Owner / Delete Permission Tests

    func testOwnerCanDeleteOwnCollaborativeList() {
        viewModel.createList(name: "My List", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let id = list.id
        let initialCount = viewModel.lists.count

        viewModel.deleteList(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.lists.count, initialCount - 1)
        XCTAssertNil(viewModel.getList(id: id))
    }

    func testNonOwnerCannotDeleteSharedCollaborativeList() {
        let shared = makeSharedList()
        viewModel.importList(shared)

        let countBeforeAttempt = viewModel.lists.count
        guard let idx = viewModel.lists.firstIndex(where: { $0.id == shared.id }) else {
            return XCTFail("Shared list not found")
        }

        viewModel.deleteList(at: IndexSet(integer: idx))

        XCTAssertEqual(viewModel.lists.count, countBeforeAttempt,
                       "Non-owner should not be able to delete a collaborative list")
        XCTAssertNotNil(viewModel.getList(id: shared.id))
    }

    func testAnyoneCanDeleteNonCollaborativeList() {
        viewModel.createList(name: "Regular", items: ["A"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.ownerId = otherUserId           // Different owner but non-collaborative
        viewModel.replaceList(list)

        let initialCount = viewModel.lists.count
        viewModel.deleteList(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.lists.count, initialCount - 1,
                       "Non-collaborative lists can be deleted regardless of ownership")
    }

    func testCanDeleteListHelper() {
        viewModel.createList(name: "Owned", items: ["A"], isCollaborative: true)
        let owned = viewModel.lists.first!

        let shared = makeSharedList(name: "Shared")
        viewModel.importList(shared)
        let importedShared = viewModel.getList(id: shared.id)!

        XCTAssertTrue(viewModel.canDeleteList(owned),    "Owner can delete their own collaborative list")
        XCTAssertFalse(viewModel.canDeleteList(importedShared), "Non-owner cannot delete a shared collaborative list")
    }

    func testDeleteOnlyRemovesAllowedListsInBatchOperation() {
        // Owned collaborative
        viewModel.createList(name: "Owned", items: ["A"], isCollaborative: true)

        // Shared collaborative (non-deletable)
        let shared = makeSharedList(name: "Shared")
        viewModel.importList(shared)

        // Regular list (always deletable)
        viewModel.createList(name: "Regular", items: ["C"], isCollaborative: false)

        let initialCount = viewModel.lists.count
        viewModel.deleteList(at: IndexSet(0..<initialCount)) // Try to delete everything

        // Only the non-deletable shared list should survive
        XCTAssertEqual(viewModel.lists.count, 1, "Only the shared non-owned list should remain")
        XCTAssertEqual(viewModel.lists.first?.name, "Shared")
    }

    // MARK: - canEditList Tests

    func testOwnerCanEditOwnCollaborativeList() {
        viewModel.createList(name: "Mine", items: ["A"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }

        XCTAssertTrue(viewModel.canEditList(list),
                      "Owner should be able to structurally edit their own collaborative list")
    }

    func testNonOwnerCannotEditSharedCollaborativeList() {
        let shared = makeSharedList()
        viewModel.importList(shared)
        guard let imported = viewModel.getList(id: shared.id) else { return XCTFail() }

        XCTAssertFalse(viewModel.canEditList(imported),
                       "Non-owner should not be able to structurally edit a shared collaborative list")
    }

    func testAnyoneCanEditNonCollaborativeList() {
        viewModel.createList(name: "Regular", items: ["A"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.ownerId = otherUserId  // Not the current user
        viewModel.replaceList(list)
        let updated = viewModel.lists.first!

        XCTAssertTrue(viewModel.canEditList(updated),
                      "Non-collaborative lists can always be edited by any user")
    }

    func testOwnerCanEditOwnRegularList() {
        viewModel.createList(name: "Regular", items: ["A"], isCollaborative: false)
        guard let list = viewModel.lists.first else { return XCTFail() }

        XCTAssertTrue(viewModel.canEditList(list))
    }

    // MARK: - leaveList Tests

    func testLeaveListRemovesSharedCollaborativeList() {
        let shared = makeSharedList(name: "Shared Movies")
        viewModel.importList(shared)

        let initialCount = viewModel.lists.count
        viewModel.leaveList(id: shared.id)

        XCTAssertEqual(viewModel.lists.count, initialCount - 1, "Leave should remove the list locally")
        XCTAssertNil(viewModel.getList(id: shared.id), "List should be gone after leaving")
    }

    func testLeaveListDoesNotAffectOtherLists() {
        viewModel.createList(name: "My List", items: ["X"], isCollaborative: false)

        let shared = makeSharedList(name: "Shared")
        viewModel.importList(shared)

        viewModel.leaveList(id: shared.id)

        XCTAssertNotNil(viewModel.lists.first(where: { $0.name == "My List" }),
                        "Leaving a shared list should not affect other lists")
    }

    func testLeaveListIsPersistedToStorage() {
        let shared = makeSharedList()
        viewModel.importList(shared)
        viewModel.leaveList(id: shared.id)

        // Create a new ViewModel to reload from storage (simulates app restart)
        let freshVM = ListsViewModel(storage: storage)
        XCTAssertNil(freshVM.getList(id: shared.id),
                     "Left list should not reappear after app restart")
    }

    func testLeaveNonExistentListDoesNotCrash() {
        viewModel.leaveList(id: UUID())  // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - importList: Collaborative Lists Preserve Identity

    func testImportCollaborativeListPreservesOriginalId() {
        let shared = makeSharedList(name: "Shared List")
        let originalId = shared.id

        viewModel.importList(shared)

        XCTAssertNotNil(viewModel.getList(id: originalId),
                        "Collaborative import must preserve the original list ID so contributions route correctly")
    }

    func testImportCollaborativeListPreservesOriginalOwnerId() {
        let shared = makeSharedList()
        viewModel.importList(shared)

        guard let imported = viewModel.getList(id: shared.id) else { return XCTFail() }
        XCTAssertEqual(imported.ownerId, otherUserId,
                       "Collaborative import must preserve the original owner's ID")
        XCTAssertNotEqual(imported.ownerId, currentUserId,
                          "Importer should NOT become the owner of a collaborative list")
    }

    func testImportCollaborativeListPreservesItems() {
        var shared = makeSharedList()
        shared.items = [RankleItem(title: "Alpha"), RankleItem(title: "Beta")]
        viewModel.importList(shared)

        guard let imported = viewModel.getList(id: shared.id) else { return XCTFail() }
        XCTAssertEqual(imported.items.count, 2)
        XCTAssertEqual(imported.items.map { $0.title }, ["Alpha", "Beta"])
    }

    func testImportCollaborativeListDuplicatePrevented() {
        let shared = makeSharedList()

        let initialCount = viewModel.lists.count
        viewModel.importList(shared)
        viewModel.importList(shared)  // Second import of the same list

        XCTAssertEqual(viewModel.lists.count, initialCount + 1,
                       "Importing the same collaborative list twice should add it only once")
    }

    // MARK: - importList: Non-Collaborative Lists Get New Identity

    func testImportNonCollaborativeListGetsNewId() {
        let originalId = UUID()
        let regular = RankleList(id: originalId, name: "Regular", items: [RankleItem(title: "A")])
        // isCollaborative is false by default

        viewModel.importList(regular)

        XCTAssertNil(viewModel.getList(id: originalId),
                     "Non-collaborative import should not use the original ID")
        XCTAssertEqual(viewModel.lists.last?.name, "Regular")
        XCTAssertNotEqual(viewModel.lists.last?.id, originalId,
                          "Non-collaborative import should receive a fresh UUID")
    }

    func testImportNonCollaborativeListCurrentUserBecomesOwner() {
        var regular = RankleList(name: "Regular", items: [RankleItem(title: "A")])
        regular.ownerId = otherUserId  // Someone else's list

        viewModel.importList(regular)

        XCTAssertEqual(viewModel.lists.last?.ownerId, currentUserId,
                       "Non-collaborative import gives ownership to the importer")
    }

    // MARK: - Collaboration Toggle

    func testOwnerCanEnableCollaboration() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        guard let list = viewModel.lists.first else { return XCTFail() }

        viewModel.setCollaborative(true, for: list.id)

        let updated = viewModel.getList(id: list.id)!
        XCTAssertTrue(updated.isCollaborative)
        XCTAssertEqual(updated.ownerId, currentUserId, "Owner should remain after enabling collaboration")
    }

    func testOwnerCanDisableCollaboration() {
        viewModel.createList(name: "Collaborative", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }

        let ranking = CollaboratorRanking(userId: otherUserId, ranking: list.items.map { $0.id })
        viewModel.upsertContribution(listId: list.id, ranking: ranking)
        viewModel.setCollaborative(false, for: list.id)

        let updated = viewModel.getList(id: list.id)!
        XCTAssertFalse(updated.isCollaborative)
        XCTAssertTrue(updated.collaborators.isEmpty, "Disabling collaboration should clear all contributions")
    }

    func testNonOwnerCannotEnableCollaboration() {
        viewModel.createList(name: "Regular", items: ["A"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.ownerId = otherUserId
        viewModel.replaceList(list)

        viewModel.setCollaborative(true, for: list.id)

        XCTAssertFalse(viewModel.getList(id: list.id)!.isCollaborative,
                       "Non-owner should not be able to enable collaboration")
    }

    func testNonOwnerCannotDisableCollaboration() {
        viewModel.createList(name: "Shared", items: ["A"], isCollaborative: true)
        var list = viewModel.lists.first!
        list.ownerId = otherUserId
        viewModel.replaceList(list)

        viewModel.setCollaborative(false, for: list.id)

        XCTAssertTrue(viewModel.getList(id: list.id)!.isCollaborative,
                      "Non-owner should not be able to disable collaboration")
    }

    func testEnablingCollaborationRemovesMediaFromItems() {
        viewModel.createList(name: "With Media", items: ["A"], isCollaborative: false)
        var list = viewModel.lists.first!
        list.items[0].media.append(MediaItem(type: .image, filename: "test.jpg"))
        viewModel.replaceList(list)

        viewModel.setCollaborative(true, for: list.id)

        let updated = viewModel.getList(id: list.id)!
        XCTAssertTrue(updated.isCollaborative)
        XCTAssertTrue(updated.items.allSatisfy { $0.media.isEmpty },
                      "All items must have media removed when collaboration is enabled")
    }

    // MARK: - Contribution Tests

    func testOwnerContributionIsSaved() {
        viewModel.createList(name: "Movies", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        let ranking = CollaboratorRanking(userId: currentUserId, ranking: [ids[2], ids[0], ids[1]])
        viewModel.upsertContribution(listId: list.id, ranking: ranking)

        let updated = viewModel.getList(id: list.id)!
        XCTAssertEqual(updated.collaborators.count, 1)
        XCTAssertEqual(updated.collaborators.first?.userId, currentUserId)
        XCTAssertEqual(updated.collaborators.first?.ranking, [ids[2], ids[0], ids[1]])
    }

    func testContributionFromDifferentUserIsAccepted() {
        viewModel.createList(name: "Foods", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        // Importer contributes using otherUserId
        let ranking = CollaboratorRanking(userId: otherUserId, ranking: ids)
        viewModel.upsertContribution(listId: list.id, ranking: ranking)

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 1)
    }

    func testResubmittingRankingUpdatesExisting() {
        viewModel.createList(name: "Songs", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        let first  = CollaboratorRanking(userId: currentUserId, ranking: ids)
        let second = CollaboratorRanking(userId: currentUserId, ranking: Array(ids.reversed()))

        viewModel.upsertContribution(listId: list.id, ranking: first)
        viewModel.upsertContribution(listId: list.id, ranking: second)

        let updated = viewModel.getList(id: list.id)!
        XCTAssertEqual(updated.collaborators.count, 1, "Resubmission should update, not duplicate")
        XCTAssertEqual(updated.collaborators.first?.ranking, Array(ids.reversed()),
                       "Should store the most recent ranking")
    }

    func testMultipleUserContributionsCoexist() {
        viewModel.createList(name: "Books", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }
        let user3 = UUID()

        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: currentUserId, ranking: ids))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: otherUserId,   ranking: Array(ids.reversed())))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: user3,         ranking: ids))

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 3)
    }

    func testContributionOnNonCollaborativeListIsIgnored() {
        viewModel.createList(name: "Regular", items: ["A", "B"], isCollaborative: false)
        guard let list = viewModel.lists.first else { return XCTFail() }

        viewModel.upsertContribution(listId: list.id,
                                     ranking: CollaboratorRanking(userId: currentUserId, ranking: list.items.map { $0.id }))

        XCTAssertTrue(viewModel.getList(id: list.id)!.collaborators.isEmpty,
                      "Non-collaborative lists must not store contributions")
    }

    func testContributionOnNonExistentListDoesNotCrash() {
        viewModel.upsertContribution(listId: UUID(),
                                     ranking: CollaboratorRanking(userId: currentUserId, ranking: []))
        XCTAssertTrue(true)
    }

    func testContributionUpdatesAggregatedItemsArray() {
        viewModel.createList(name: "Auto Update", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        let ranking = CollaboratorRanking(userId: currentUserId, ranking: Array(ids.reversed()))
        viewModel.upsertContribution(listId: list.id, ranking: ranking)

        let updated = viewModel.getList(id: list.id)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(updated.items.map { $0.id }, aggregated.map { $0.id },
                       "items array must be kept in sync with the aggregate after each contribution")
    }

    // MARK: - Aggregated Ranking Correctness

    func testAggregateReflectsAllCollaborators() {
        viewModel.createList(name: "Shows", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        // All three rank B first
        let user3 = UUID()
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: currentUserId, ranking: [ids[1], ids[0], ids[2]]))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: otherUserId,   ranking: [ids[1], ids[2], ids[0]]))
        viewModel.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: user3,         ranking: [ids[1], ids[0], ids[2]]))

        let updated   = viewModel.getList(id: list.id)!
        let aggregated = viewModel.getAggregateRanking(for: updated)
        XCTAssertEqual(aggregated.first?.id, ids[1], "B should be ranked first since all collaborators prefer it")
    }

    // MARK: - Refresh

    func testRefreshReloadsFromStorage() {
        viewModel.createList(name: "Initial", items: ["A"], isCollaborative: false)
        guard let list = viewModel.lists.first else { return XCTFail() }

        // Simulate external edit
        var lists = storage.loadLists()
        lists[0].name = "Modified"
        storage.saveLists(lists)

        viewModel.refresh()

        XCTAssertEqual(viewModel.getList(id: list.id)?.name, "Modified")
    }

    func testRefreshPicksUpExternalContributions() {
        viewModel.createList(name: "Sync", items: ["A", "B", "C"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let ids = list.items.map { $0.id }

        viewModel.upsertContribution(listId: list.id,
                                     ranking: CollaboratorRanking(userId: currentUserId, ranking: ids))

        // Simulate an external contribution arriving via storage
        var stored = storage.loadLists()
        var storedList = stored.first!
        storedList.collaborators.append(
            CollaboratorRanking(userId: UUID(), ranking: Array(ids.reversed()))
        )
        storedList.items = storage.aggregateRanking(for: storedList)
        stored[0] = storedList
        storage.saveLists(stored)

        viewModel.refresh()

        XCTAssertEqual(viewModel.getList(id: list.id)!.collaborators.count, 2,
                       "Refresh should surface contributions written directly to storage")
    }

    // MARK: - Misc edge cases

    func testDeleteWithInvalidIndexDoesNotCrash() {
        viewModel.createList(name: "Test", items: ["A"], isCollaborative: false)
        viewModel.deleteList(at: IndexSet(integer: 999))
        XCTAssertFalse(viewModel.lists.isEmpty, "Invalid index delete should be a no-op")
    }

    func testGetListReturnsNilForUnknownId() {
        XCTAssertNil(viewModel.getList(id: UUID()))
    }

    func testSetCollaborativeOnUnknownIdDoesNotCrash() {
        viewModel.setCollaborative(true, for: UUID())
        viewModel.setCollaborative(false, for: UUID())
        XCTAssertTrue(true)
    }

    func testRenameCollaborativeListPreservesContributors() {
        viewModel.createList(name: "Movies", items: ["A", "B"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }

        viewModel.upsertContribution(listId: list.id,
                                     ranking: CollaboratorRanking(userId: otherUserId, ranking: list.items.map { $0.id }))
        viewModel.renameList(list.id, newName: "Best Movies")

        let updated = viewModel.getList(id: list.id)!
        XCTAssertEqual(updated.name, "Best Movies")
        XCTAssertEqual(updated.collaborators.count, 1, "Rename should not clear contributions")
    }

    // MARK: - Persistence across restarts

    func testOwnershipPersistedAcrossRestarts() {
        viewModel.createList(name: "Collab", items: ["A"], isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail() }
        let id = list.id
        let ownerIdBeforeRestart = list.ownerId

        let freshVM = ListsViewModel(storage: storage)
        XCTAssertEqual(freshVM.getList(id: id)?.ownerId, ownerIdBeforeRestart,
                       "ownerId must be preserved after app restart")
    }

    func testImportedCollaborativeListPersistedAcrossRestarts() {
        let shared = makeSharedList(name: "Shared Collab")
        viewModel.importList(shared)

        let freshVM = ListsViewModel(storage: storage)
        guard let loaded = freshVM.getList(id: shared.id) else {
            return XCTFail("Imported collaborative list should survive app restart")
        }
        XCTAssertEqual(loaded.ownerId, otherUserId)
        XCTAssertTrue(loaded.isCollaborative)
    }
}
