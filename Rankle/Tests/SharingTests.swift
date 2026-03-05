import XCTest
@testable import Rankle

final class SharingTests: XCTestCase {
    private var sharingService: SharingService!
    private var tempDir: URL!
    private var storage: StorageService!
    // Use a fresh viewModel with isolated storage for every test
    private var viewModel: ListsViewModel!

    // A non-collaborative list owned by the test user
    private var regularList: RankleList!
    // A collaborative list owned by a different user (simulates a shared list)
    private var collaborativeList: RankleList!
    private let otherUserId = UUID()

    override func setUp() {
        super.setUp()
        sharingService = SharingService.shared

        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rankle-sharing-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)

        regularList = RankleList(
            name: "Test Movies",
            items: [
                RankleItem(title: "The Matrix"),
                RankleItem(title: "Inception"),
                RankleItem(title: "Interstellar"),
            ],
            color: .blue
        )

        var collab = RankleList(
            name: "Shared Songs",
            items: [
                RankleItem(title: "Song A"),
                RankleItem(title: "Song B"),
            ],
            color: .green,
            isCollaborative: true
        )
        collab.ownerId = otherUserId
        collaborativeList = collab
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil; storage = nil; viewModel = nil
        sharingService = nil; regularList = nil; collaborativeList = nil
        super.tearDown()
    }

    // MARK: - Deep Link Generation

    func testDeepLinkHasCorrectSchemeAndHost() {
        let url = sharingService.generateDeepLink(for: regularList)
        XCTAssertNotNil(url, "Deep link must be generated")
        XCTAssertEqual(url?.scheme, "rankle")
        XCTAssertEqual(url?.host, "i")
    }

    func testDeepLinkContainsNonEmptyToken() {
        let url = sharingService.generateDeepLink(for: regularList)!
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        XCTAssertFalse(path.isEmpty, "Deep link must contain a non-empty token")
    }

    func testDeepLinkGenerationForEmptyList() {
        let empty = RankleList(name: "Empty", items: [])
        let url = sharingService.generateDeepLink(for: empty)
        XCTAssertNotNil(url, "Deep link should be generatable for an empty list")
    }

    // MARK: - Deep Link Parsing: Round-trip (non-collaborative)

    func testNonCollaborativeDeepLinkRoundTrip() {
        guard let url = sharingService.generateDeepLink(for: regularList) else {
            return XCTFail("Link generation failed")
        }
        guard let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail("Link parsing failed")
        }
        XCTAssertEqual(parsed.name, regularList.name)
        XCTAssertEqual(parsed.items.count, regularList.items.count)
        XCTAssertEqual(parsed.items.map { $0.title }, regularList.items.map { $0.title })
    }

    func testNonCollaborativeDeepLinkPreservesItemIds() {
        guard let url = sharingService.generateDeepLink(for: regularList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }
        XCTAssertEqual(parsed.items.map { $0.id }, regularList.items.map { $0.id },
                       "Item IDs must survive encode → decode")
    }

    // MARK: - Deep Link Parsing: Round-trip (collaborative)

    func testCollaborativeDeepLinkRoundTripPreservesListId() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }
        XCTAssertEqual(parsed.id, collaborativeList.id,
                       "The original list ID must survive the encode → decode round-trip")
    }

    func testCollaborativeDeepLinkRoundTripPreservesOwnerId() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }
        XCTAssertEqual(parsed.ownerId, otherUserId,
                       "The original ownerId must survive the encode → decode round-trip")
    }

    func testCollaborativeDeepLinkRoundTripPreservesCollaborativeFlag() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }
        XCTAssertTrue(parsed.isCollaborative)
    }

    // MARK: - Import: Non-collaborative list

    func testImportNonCollaborativeListAddsToCollection() {
        let initialCount = viewModel.lists.count
        viewModel.importList(regularList)
        XCTAssertEqual(viewModel.lists.count, initialCount + 1)
        XCTAssertEqual(viewModel.lists.last?.name, regularList.name)
    }

    func testImportNonCollaborativeListGetsNewId() {
        viewModel.importList(regularList)
        XCTAssertNil(viewModel.getList(id: regularList.id),
                     "Non-collaborative import must not reuse the original ID")
        XCTAssertNotEqual(viewModel.lists.last?.id, regularList.id)
    }

    func testImportNonCollaborativeListCurrentUserBecomesOwner() {
        let currentUserId = UserService.shared.currentUserId
        var someoneElsesList = regularList!
        someoneElsesList.ownerId = UUID() // Someone else originally owned it
        viewModel.importList(someoneElsesList)
        XCTAssertEqual(viewModel.lists.last?.ownerId, currentUserId,
                       "Importing a non-collaborative list gives ownership to the importer")
    }

    // MARK: - Import: Collaborative list via deep link

    func testImportCollaborativeListViaLinkPreservesId() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }

        viewModel.importList(parsed)

        XCTAssertNotNil(viewModel.getList(id: collaborativeList.id),
                        "Importing a collaborative list must preserve the original ID")
    }

    func testImportCollaborativeListViaLinkPreservesOwnerId() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }

        viewModel.importList(parsed)

        let imported = viewModel.getList(id: collaborativeList.id)!
        XCTAssertEqual(imported.ownerId, otherUserId,
                       "Importing must not reassign ownership — the original owner must remain")
        XCTAssertNotEqual(imported.ownerId, UserService.shared.currentUserId,
                          "The importer must not become the owner of a collaborative list")
    }

    func testImportCollaborativeListViaLinkImporterIsNotOwner() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }

        viewModel.importList(parsed)

        let imported = viewModel.getList(id: collaborativeList.id)!
        XCTAssertFalse(viewModel.canDeleteList(imported),
                       "Importer should not be able to delete a list they don't own")
        XCTAssertFalse(viewModel.canEditList(imported),
                       "Importer should not be able to structurally edit a list they don't own")
    }

    func testImportCollaborativeListViaLinkImporterCanContribute() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }
        viewModel.importList(parsed)

        let imported = viewModel.getList(id: collaborativeList.id)!
        let ids = imported.items.map { $0.id }

        viewModel.upsertContribution(
            listId: imported.id,
            ranking: CollaboratorRanking(userId: UserService.shared.currentUserId, ranking: Array(ids.reversed()))
        )

        XCTAssertEqual(viewModel.getList(id: imported.id)!.collaborators.count, 1,
                       "Importer must be able to submit their own ranking as a contribution")
    }

    // MARK: - Duplicate Import Prevention

    func testDuplicateCollaborativeImportIgnored() {
        let initialCount = viewModel.lists.count
        viewModel.importList(collaborativeList)
        viewModel.importList(collaborativeList)  // Same list a second time

        XCTAssertEqual(viewModel.lists.count, initialCount + 1,
                       "Importing the same collaborative list twice must add it only once")
    }

    func testDuplicateCollaborativeImportViaLinkIgnored() {
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed1 = sharingService.parseDeepLink(url: url),
              let parsed2 = sharingService.parseDeepLink(url: url) else {
            return XCTFail()
        }

        let initialCount = viewModel.lists.count
        viewModel.importList(parsed1)
        viewModel.importList(parsed2)

        XCTAssertEqual(viewModel.lists.count, initialCount + 1,
                       "Re-importing via link must not produce a duplicate entry")
    }

    // MARK: - Contribution Link

    func testContributionLinkRoundTrip() {
        let listId    = UUID()
        let userId    = UUID()
        let ranking   = [UUID(), UUID(), UUID()]

        guard let url = sharingService.generateContributionLink(
            listId: listId, userId: userId, displayName: "Alice", ranking: ranking
        ) else {
            return XCTFail("Contribution link generation failed")
        }

        XCTAssertEqual(url.scheme, "rankle")
        XCTAssertEqual(url.host,   "cr")

        guard let contribution = sharingService.parseContribution(url: url) else {
            return XCTFail("Contribution link parsing failed")
        }

        XCTAssertEqual(contribution.listId,      listId)
        XCTAssertEqual(contribution.userId,      userId)
        XCTAssertEqual(contribution.displayName, "Alice")
        XCTAssertEqual(contribution.ranking,     ranking)
    }

    func testContributionLinkIsRejectedByListParser() {
        guard let url = sharingService.generateContributionLink(
            listId: UUID(), userId: UUID(), displayName: nil, ranking: []
        ) else {
            return XCTFail()
        }
        // A contribution link must not be parsed as a list import
        XCTAssertNil(sharingService.parseDeepLink(url: url),
                     "Contribution links must not be mistakenly parsed as list import links")
    }

    func testListLinkIsRejectedByContributionParser() {
        guard let url = sharingService.generateDeepLink(for: regularList) else { return XCTFail() }
        XCTAssertNil(sharingService.parseContribution(url: url),
                     "List import links must not be mistakenly parsed as contribution links")
    }

    // MARK: - Clipboard Text

    func testClipboardTextContainsListName() {
        let text = sharingService.generateClipboardText(for: regularList)
        XCTAssertTrue(text.contains(regularList.name), "Clipboard text must include the list name")
    }

    func testClipboardTextContainsAllItems() {
        let text = sharingService.generateClipboardText(for: regularList)
        for item in regularList.items {
            XCTAssertTrue(text.contains(item.title),
                          "Clipboard text must include every item title (\(item.title))")
        }
    }

    func testClipboardTextContainsNumberedRanking() {
        let text = sharingService.generateClipboardText(for: regularList)
        XCTAssertTrue(text.contains("1."), "Clipboard text must number the items")
    }

    // MARK: - Invalid URL Handling

    func testUnknownSchemeReturnsNil() {
        let url = URL(string: "https://example.com/i/sometoken")!
        XCTAssertNil(sharingService.parseDeepLink(url: url))
        XCTAssertNil(sharingService.parseContribution(url: url))
    }

    func testMalformedTokenReturnsNil() {
        let url = URL(string: "rankle://i/!!!notbase64!!!")!
        XCTAssertNil(sharingService.parseDeepLink(url: url))
    }

    // MARK: - Full Collaboration Flow

    /// End-to-end test: owner creates a collaborative list, shares it, a collaborator
    /// imports via the link (preserving original ID/owner), submits a ranking,
    /// and the aggregate is recomputed.
    func testFullCollaborationFlowViaDeepLink() {
        // 1. Simulated owner creates the list (ownerId = otherUserId)
        guard let url = sharingService.generateDeepLink(for: collaborativeList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            return XCTFail("Share link encoding failed")
        }

        // 2. Current user (collaborator) imports it
        viewModel.importList(parsed)
        guard let imported = viewModel.getList(id: collaborativeList.id) else {
            return XCTFail("Import failed")
        }

        // 3. Verify identity is intact
        XCTAssertEqual(imported.id,      collaborativeList.id)
        XCTAssertEqual(imported.ownerId, otherUserId)
        XCTAssertTrue(imported.isCollaborative)

        // 4. Collaborator submits their ranking
        let ids     = imported.items.map { $0.id }
        let myRank  = Array(ids.reversed())
        viewModel.upsertContribution(
            listId: imported.id,
            ranking: CollaboratorRanking(
                userId:    UserService.shared.currentUserId,
                ranking:   myRank,
                updatedAt: Date()
            )
        )

        // 5. Aggregate is available and reflects the contribution
        let afterContrib = viewModel.getList(id: imported.id)!
        XCTAssertEqual(afterContrib.collaborators.count, 1)
        XCTAssertEqual(afterContrib.collaborators.first?.ranking, myRank)
        XCTAssertEqual(afterContrib.items.count, collaborativeList.items.count)
    }
}
