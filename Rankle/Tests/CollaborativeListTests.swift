import XCTest
@testable import Rankle

final class CollaborativeListTests: XCTestCase {

    func testOwnerSetCollaborativeAndDisable() {
        let vm = ListsViewModel()
        // Create as non-collaborative by owner (current user)
        vm.createList(name: "Mine", items: ["A","B","C"], isCollaborative: false)
        guard let listId = vm.lists.last?.id else { return XCTFail("missing list") }

        // Enable collaboration
        vm.setCollaborative(true, for: listId)
        var list = vm.lists.last!
        XCTAssertTrue(list.isCollaborative)

        // Add collaborators then disable as owner
        let items = list.items
        vm.upsertContribution(listId: listId, ranking: CollaboratorRanking(userId: UUID(), ranking: items.map { $0.id }))
        vm.upsertContribution(listId: listId, ranking: CollaboratorRanking(userId: UUID(), ranking: items.reversed().map { $0.id }))
        list = vm.lists.last!
        XCTAssertEqual(list.collaborators.count, 2)

        vm.setCollaborative(false, for: listId)
        list = vm.lists.last!
        XCTAssertFalse(list.isCollaborative)
        XCTAssertTrue(list.collaborators.isEmpty, "Disabling collaboration should clear collaborators")
    }

    func testNonOwnerCannotDisable() {
        let vm = ListsViewModel()
        vm.createList(name: "Not Mine", items: ["A","B"], isCollaborative: true)
        guard var list = vm.lists.last else { return XCTFail("missing list") }
        // Force ownerId to someone else
        list.ownerId = UUID()
        vm.replaceList(list)
        // Attempt to disable
        vm.setCollaborative(false, for: list.id)
        let updated = vm.lists.last!
        XCTAssertTrue(updated.isCollaborative, "Non-owner should not be able to disable collaboration")
    }

    func testNonOwnerCannotDeleteCollaborative() {
        let vm = ListsViewModel()
        // Create collaborative list
        vm.createList(name: "Shared", items: ["A","B"], isCollaborative: true)
        guard var list = vm.lists.last else { return XCTFail("missing list") }
        // Make someone else the owner
        list.ownerId = UUID()
        vm.replaceList(list)
        let initialCount = vm.lists.count
        // Attempt delete at last index
        vm.deleteList(at: IndexSet(integer: initialCount - 1))
        // Count should be unchanged
        XCTAssertEqual(vm.lists.count, initialCount, "Non-owner should not be able to delete a collaborative list")
    }

    func testUpsertContributionIsIdempotentForUser() {
        let vm = ListsViewModel()
        // Build real RankleItem ids so ranking points to valid ids
        vm.createList(name: "Collab", items: ["A","B","C"], isCollaborative: true)
        guard let list = vm.lists.last else { return XCTFail("missing list") }
        let ids = list.items.map { $0.id }
        let uid = UUID()
        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: ids))
        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: ids.reversed()))
        let updated = vm.lists.last!
        XCTAssertEqual(updated.collaborators.count, 1, "Repeated links should update, not duplicate")
        XCTAssertEqual(updated.collaborators.first?.ranking, ids.reversed())
    }

    func testAggregationHandlesMissingItemsInRanking() {
        // Three items, one collaborator only ranks two
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Collab", items: [a,b,c], isCollaborative: true)
        // Only ranks A and C (missing B)
        list.collaborators = [
            CollaboratorRanking(userId: UUID(), ranking: [a.id, c.id])
        ]
        let agg = StorageService().aggregateRanking(for: list)
        // Unranked item B should be treated as bottom; A should come before C or B
        XCTAssertEqual(agg.first?.id, a.id)
        XCTAssertTrue(agg.contains(where: { $0.id == b.id }))
        XCTAssertTrue(agg.contains(where: { $0.id == c.id }))
    }

    func testSetCollaborativeUnknownListNoCrash() {
        let vm = ListsViewModel()
        // Just call with a random id; should not crash
        vm.setCollaborative(true, for: UUID())
        vm.setCollaborative(false, for: UUID())
        XCTAssertTrue(true)
    }
}
