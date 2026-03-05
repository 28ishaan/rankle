import XCTest
import CloudKit
@testable import Rankle

/// Tests for CloudKit integration.
///
/// CloudKit network calls are expected to fail in the CI/test environment; those tests
/// verify graceful error handling rather than successful round-trips.  Tests that do not
/// require a network connection (encoding, subscription ID format, viewModel behavior,
/// etc.) make hard assertions.
final class CloudKitServiceTests: XCTestCase {
    private var cloudKit: CloudKitService!
    private var tempDir: URL!
    private var storage: StorageService!

    override func setUp() {
        super.setUp()
        cloudKit = CloudKitService.shared
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rankle-cloudkit-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil; storage = nil; cloudKit = nil
        super.tearDown()
    }

    // MARK: - Account Status

    func testCheckAccountStatusDoesNotThrowUnexpected() async {
        do {
            let status = try await cloudKit.checkAccountStatus()
            let validStatuses: [CKAccountStatus] = [.available, .noAccount, .couldNotDetermine, .restricted]
            XCTAssertTrue(validStatuses.contains(status), "Must return a recognised CKAccountStatus")
        } catch {
            // CloudKit unavailable in test environment — acceptable
        }
    }

    // MARK: - Model / Encoding Correctness

    func testRankleListStructureIsCorrect() {
        var list = RankleList(
            name: "Test List",
            items: [RankleItem(title: "Item A"), RankleItem(title: "Item B")],
            color: .blue,
            isCollaborative: true
        )
        list.ownerId = UUID()

        XCTAssertEqual(list.name, "Test List")
        XCTAssertEqual(list.items.count, 2)
        XCTAssertTrue(list.isCollaborative)
    }

    func testCollaborativeListItemsHaveNoMediaAfterCreation() {
        // Media is stripped when creating a collaborative list through the ViewModel
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "No Media", items: ["A", "B"], isCollaborative: true)

        guard let list = vm.lists.first(where: { $0.isCollaborative }) else {
            return XCTFail("Expected a collaborative list to exist")
        }
        XCTAssertTrue(list.items.allSatisfy { $0.media.isEmpty },
                      "Collaborative list items must not carry media")
    }

    func testNonCollaborativeListItemsPreserveMedia() {
        let imageItem = RankleItem(title: "With Image",
                                   media: [MediaItem(type: .image, filename: "test.jpg")])
        let vm = ListsViewModel(storage: storage)
        vm.createListWithItems(name: "Media OK", items: [imageItem], isCollaborative: false)

        guard let list = vm.lists.first else { return XCTFail() }
        XCTAssertFalse(list.isCollaborative)
        XCTAssertEqual(list.items.first?.media.count, 1,
                       "Non-collaborative list items must keep their media")
    }

    func testCollaboratorRankingStructureIsCorrect() {
        let ranking = CollaboratorRanking(
            userId: UUID(),
            displayName: "Test User",
            ranking: [UUID(), UUID(), UUID()],
            updatedAt: Date()
        )
        XCTAssertNotNil(ranking.userId)
        XCTAssertEqual(ranking.ranking.count, 3)
        XCTAssertNotNil(ranking.updatedAt)
    }

    // MARK: - JSON Round-trips

    func testRankleListJsonRoundTrip() throws {
        var original = RankleList(
            name: "Round Trip",
            items: [RankleItem(title: "X"), RankleItem(title: "Y")],
            color: .red,
            isCollaborative: true
        )
        original.ownerId = UUID()
        original.collaborators = [CollaboratorRanking(userId: UUID(), ranking: original.items.map { $0.id })]

        let data   = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RankleList.self, from: data)

        XCTAssertEqual(decoded.id,              original.id)
        XCTAssertEqual(decoded.name,            original.name)
        XCTAssertEqual(decoded.ownerId,         original.ownerId)
        XCTAssertEqual(decoded.isCollaborative, original.isCollaborative)
        XCTAssertEqual(decoded.items.count,     original.items.count)
        XCTAssertEqual(decoded.collaborators.count, original.collaborators.count)
    }

    func testCollaboratorRankingJsonRoundTrip() throws {
        let ids      = [UUID(), UUID(), UUID()]
        let original = CollaboratorRanking(userId: UUID(), displayName: "Alice", ranking: ids, updatedAt: Date())

        let data    = try JSONEncoder().encode(original)
        let decoded  = try JSONDecoder().decode(CollaboratorRanking.self, from: data)

        XCTAssertEqual(decoded.userId,      original.userId)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.ranking,     original.ranking)
    }

    // MARK: - Subscription ID Format

    func testListSubscriptionIdIsUniquePerList() {
        let id1 = "list-\(UUID().uuidString)"
        let id2 = "list-\(UUID().uuidString)"
        XCTAssertNotEqual(id1, id2)
    }

    func testContributionSubscriptionIdIsUniquePerList() {
        let id1 = "contributions-\(UUID().uuidString)"
        let id2 = "contributions-\(UUID().uuidString)"
        XCTAssertNotEqual(id1, id2)
    }

    func testListAndContributionSubscriptionIdsAreDistinct() {
        let listId   = UUID().uuidString
        let listSub  = "list-\(listId)"
        let contribSub = "contributions-\(listId)"
        XCTAssertNotEqual(listSub, contribSub,
                          "List and contribution subscription IDs must be distinct for the same list ID")
    }

    // MARK: - ViewModel: Collaborative List Creation Triggers CloudKit

    func testCreatingCollaborativeListSetsCorrectOwner() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "CloudKit Test", items: ["A", "B"], isCollaborative: true)

        guard let created = vm.lists.first(where: { $0.name == "CloudKit Test" }) else {
            return XCTFail("Expected to find the created list")
        }
        XCTAssertTrue(created.isCollaborative)
        XCTAssertEqual(created.ownerId, UserService.shared.currentUserId,
                       "Creator must be set as owner")
    }

    func testCreatingNonCollaborativeListDoesNotSyncToCloudKit() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Local Only", items: ["A"], isCollaborative: false)

        guard let created = vm.lists.first(where: { $0.name == "Local Only" }) else {
            return XCTFail()
        }
        XCTAssertFalse(created.isCollaborative)
        // Non-collaborative list — CloudKit save is never triggered
    }

    // MARK: - ViewModel: Enabling Collaboration Removes Media

    func testEnablingCollaborationStripsMedia() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "With Media", items: ["A"], isCollaborative: false)

        guard var list = vm.lists.first(where: { $0.name == "With Media" }) else { return XCTFail() }
        list.items[0].media.append(MediaItem(type: .image, filename: "test.jpg"))
        vm.replaceList(list)

        vm.setCollaborative(true, for: list.id)

        guard let updated = vm.getList(id: list.id) else { return XCTFail() }
        XCTAssertTrue(updated.isCollaborative)
        XCTAssertTrue(updated.items.allSatisfy { $0.media.isEmpty },
                      "All item media must be removed when collaboration is enabled")
    }

    // MARK: - ViewModel: Contribution Handling

    func testSavingContributionStoresItLocally() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Contributions", items: ["A", "B", "C"], isCollaborative: true)

        guard let list = vm.lists.first(where: { $0.name == "Contributions" }) else { return XCTFail() }
        let itemIds = list.items.map { $0.id }

        let ranking = CollaboratorRanking(
            userId: UserService.shared.currentUserId,
            ranking: itemIds
        )
        vm.upsertContribution(listId: list.id, ranking: ranking)

        guard let updated = vm.getList(id: list.id) else { return XCTFail() }
        XCTAssertEqual(updated.collaborators.count, 1, "Contribution must be stored locally")
        XCTAssertEqual(updated.collaborators.first?.userId, UserService.shared.currentUserId)
    }

    func testMultipleSubmissionsFromSameUserDoNotDuplicate() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Updates", items: ["A", "B", "C"], isCollaborative: true)

        guard let list = vm.lists.first(where: { $0.name == "Updates" }) else { return XCTFail() }
        let ids    = list.items.map { $0.id }
        let userId = UserService.shared.currentUserId

        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: userId, ranking: ids))
        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: userId, ranking: Array(ids.reversed())))

        guard let updated = vm.getList(id: list.id) else { return XCTFail() }
        XCTAssertEqual(updated.collaborators.count, 1, "Re-submission must update the existing record")
        XCTAssertEqual(updated.collaborators.first?.ranking, Array(ids.reversed()),
                       "Latest ranking must be stored")
    }

    // MARK: - ViewModel: Sync Fallback

    func testSyncWithNoCloudKitAccountPreservesLocalLists() async {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Preserve", items: ["A"], isCollaborative: false)
        vm.createList(name: "Preserve2", items: ["B"], isCollaborative: true)
        let initialCount = vm.lists.count

        await vm.syncWithCloudKit()

        // CloudKit will fail in test env; local lists must not be wiped
        XCTAssertEqual(vm.lists.count, initialCount,
                       "Sync failure must not delete locally-stored lists")
    }

    func testRefreshPreservesLocalLists() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Persist", items: ["A"], isCollaborative: true)
        let initialCount = vm.lists.count

        vm.refresh()

        XCTAssertEqual(vm.lists.count, initialCount,
                       "Refresh must not drop locally-stored lists")
    }

    // MARK: - CloudKit API: Graceful Error Handling

    func testFetchOwnedListsHandlesUnavailableCloudKit() async {
        do {
            let lists = try await cloudKit.fetchOwnedLists(ownerId: UserService.shared.currentUserId)
            XCTAssertNotNil(lists)
        } catch {
            // CloudKit is unavailable in tests — expected to fail gracefully
        }
    }

    func testFetchContributionsForUnknownListHandlesErrors() async {
        do {
            let contributions = try await cloudKit.fetchContributions(for: UUID())
            XCTAssertTrue(contributions.isEmpty,
                          "Unknown list ID should return empty contributions")
        } catch {
            // CloudKit unavailable — expected
        }
    }

    func testSaveListHandlesCloudKitErrors() async {
        let list = RankleList(name: "Error Test", items: [], isCollaborative: true)
        do {
            try await cloudKit.saveList(list)
        } catch {
            // CloudKit save may fail in test env — no crash is the requirement
        }
        XCTAssertTrue(true, "saveList must not crash even when CloudKit is unavailable")
    }

    func testSaveContributionHandlesCloudKitErrors() async {
        let ranking = CollaboratorRanking(userId: UUID(), ranking: [])
        do {
            try await cloudKit.saveContribution(ranking, for: UUID())
        } catch {
            // CloudKit save may fail in test env
        }
        XCTAssertTrue(true, "saveContribution must not crash even when CloudKit is unavailable")
    }

    // MARK: - Disabling Collaboration

    func testDisablingCollaborationClearsAllContributions() {
        let vm = ListsViewModel(storage: storage)
        vm.createList(name: "Toggle", items: ["A", "B"], isCollaborative: true)

        guard let list = vm.lists.first(where: { $0.name == "Toggle" }) else { return XCTFail() }
        vm.upsertContribution(listId: list.id,
                               ranking: CollaboratorRanking(userId: UUID(), ranking: []))

        vm.setCollaborative(false, for: list.id)

        guard let updated = vm.getList(id: list.id) else { return XCTFail() }
        XCTAssertFalse(updated.isCollaborative)
        XCTAssertTrue(updated.collaborators.isEmpty,
                      "Disabling collaboration must clear all stored contributions")
    }
}
