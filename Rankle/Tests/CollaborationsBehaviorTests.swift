import XCTest
import SwiftUI
@testable import Rankle

final class CollaborationsBehaviorTests: XCTestCase {
    private var tempDir: URL! = nil
    private var storage: StorageService! = nil
    private var viewModel: ListsViewModel! = nil

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-collab-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        viewModel = nil
        super.tearDown()
    }

    func testNonOwnerCannotDisableCollaborative() {
        // Create a collaborative list owned by current user
        viewModel.createList(name: "Test", items: ["A", "B"], color: .cyan, isCollaborative: true)
        guard var list = viewModel.lists.first else { return XCTFail("Expected list") }

        // Make another user the owner
        let someoneElse = UUID()
        list.ownerId = someoneElse
        list.isCollaborative = true
        viewModel.replaceList(list)

        // Attempt to disable as non-owner
        viewModel.setCollaborative(false, for: list.id)

        // Still collaborative
        XCTAssertTrue(viewModel.lists.first?.isCollaborative == true)
    }

    func testOwnerCanDisableCollaborativeAndClearsCollaborators() {
        // Create as current user (owner)
        viewModel.createList(name: "Test", items: ["A", "B"], color: .cyan, isCollaborative: true)
        guard var list = viewModel.lists.first else { return XCTFail("Expected list") }

        // Add a fake collaborator
        let collab = CollaboratorRanking(userId: UUID(), ranking: list.items.map { $0.id })
        list.collaborators = [collab]
        viewModel.replaceList(list)

        // Disable as owner
        viewModel.setCollaborative(false, for: list.id)

        XCTAssertEqual(viewModel.lists.first?.isCollaborative, false)
        XCTAssertEqual(viewModel.lists.first?.collaborators.count, 0)
    }

    func testUpsertContributionAggregatesIntoItemsOrder() {
        // Setup list with 3 items
        viewModel.createList(name: "Movies", items: ["A","B","C"], color: .cyan, isCollaborative: true)
        guard let list = viewModel.lists.first else { return XCTFail("Expected list") }
        let ids = list.items.map { $0.id }

        // Two collaborators with different orders
        let collab1 = CollaboratorRanking(userId: UUID(), ranking: [ids[0], ids[1], ids[2]])
        let collab2 = CollaboratorRanking(userId: UUID(), ranking: [ids[2], ids[1], ids[0]])

        viewModel.upsertContribution(listId: list.id, ranking: collab1)
        viewModel.upsertContribution(listId: list.id, ranking: collab2)

        // The items array should be aggregated according to storage.aggregateRanking
        guard let updated = viewModel.lists.first else { return XCTFail("Expected updated list") }
        let expected = storage.aggregateRanking(for: updated)
        XCTAssertEqual(updated.items.map { $0.id }, expected.map { $0.id })
    }
}


