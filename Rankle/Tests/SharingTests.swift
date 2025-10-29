import XCTest
@testable import Rankle

final class SharingTests: XCTestCase {
    var sharingService: SharingService!
    var testList: RankleList!
    
    override func setUp() {
        super.setUp()
        sharingService = SharingService.shared
        testList = RankleList(
            name: "Test Movies",
            items: [
                RankleItem(title: "The Matrix"),
                RankleItem(title: "Inception"),
                RankleItem(title: "Interstellar")
            ],
            color: .blue
        )
    }
    
    func testDeepLinkGeneration() {
        let url = sharingService.generateDeepLink(for: testList)
        
        XCTAssertNotNil(url, "Deep link should be generated")
        XCTAssertEqual(url?.scheme, "rankle", "URL scheme should be 'rankle'")
        XCTAssertEqual(url?.host, "i", "URL host should be 'i' for compact links")
    }
    
    func testDeepLinkParsing() {
        guard let url = sharingService.generateDeepLink(for: testList) else {
            XCTFail("Failed to generate deep link")
            return
        }
        
        let parsed = sharingService.parseDeepLink(url: url)
        
        XCTAssertNotNil(parsed, "Should parse deep link successfully")
        XCTAssertEqual(parsed?.name, testList.name, "List name should match")
        XCTAssertEqual(parsed?.items.count, testList.items.count, "Item count should match")
        XCTAssertEqual(parsed?.items[0].title, "The Matrix", "First item should match")
        XCTAssertEqual(parsed?.items[1].title, "Inception", "Second item should match")
        XCTAssertEqual(parsed?.items[2].title, "Interstellar", "Third item should match")
    }
    
    func testDeepLinkRoundTrip() {
        // Generate -> Parse -> Should get equivalent list
        guard let url = sharingService.generateDeepLink(for: testList),
              let parsed = sharingService.parseDeepLink(url: url) else {
            XCTFail("Round trip failed")
            return
        }
        
        XCTAssertEqual(parsed.name, testList.name)
        XCTAssertEqual(parsed.items.map { $0.title }, testList.items.map { $0.title })
    }
    
    func testClipboardTextGeneration() {
        let text = sharingService.generateClipboardText(for: testList)
        
        XCTAssertTrue(text.contains("Test Movies"), "Should contain list name")
        XCTAssertTrue(text.contains("1. The Matrix"), "Should contain first item")
        XCTAssertTrue(text.contains("2. Inception"), "Should contain second item")
        XCTAssertTrue(text.contains("3. Interstellar"), "Should contain third item")
        XCTAssertTrue(text.contains("Shared from Rankle"), "Should contain app attribution")
    }
    
    func testInvalidDeepLinkParsing() {
        let invalidURL = URL(string: "rankle://import?data=invalid")!
        let parsed = sharingService.parseDeepLink(url: invalidURL)
        
        XCTAssertNil(parsed, "Invalid deep link should return nil")
    }
    
    func testWrongSchemeDeepLink() {
        let wrongScheme = URL(string: "http://import?data=test")!
        let parsed = sharingService.parseDeepLink(url: wrongScheme)
        
        XCTAssertNil(parsed, "Wrong scheme should return nil")
    }
    
    func testEmptyListSharing() {
        let emptyList = RankleList(name: "Empty", items: [], color: .red)
        
        let url = sharingService.generateDeepLink(for: emptyList)
        XCTAssertNotNil(url, "Should generate URL for empty list")
        
        if let url = url {
            let parsed = sharingService.parseDeepLink(url: url)
            XCTAssertEqual(parsed?.items.count, 0, "Parsed list should be empty")
        }
    }
    
    func testListsViewModelImport() {
        let viewModel = ListsViewModel()
        let initialCount = viewModel.lists.count
        
        viewModel.importList(testList)
        
        XCTAssertEqual(viewModel.lists.count, initialCount + 1, "Should add one list")
        XCTAssertEqual(viewModel.lists.last?.name, testList.name, "Imported list name should match")
        XCTAssertNotEqual(viewModel.lists.last?.id, testList.id, "Imported list should have new ID")
    }
}

final class CollaborativeTests: XCTestCase {
    func testAggregationAveragePositions() {
        // Items
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        var list = RankleList(name: "Collab", items: [a, b, c], isCollaborative: true)
        // Two collaborators
        let r1 = CollaboratorRanking(userId: UUID(), ranking: [a.id, b.id, c.id])
        let r2 = CollaboratorRanking(userId: UUID(), ranking: [b.id, c.id, a.id])
        list.collaborators = [r1, r2]
        let aggregated = StorageService().aggregateRanking(for: list)
        // B should be top (1 and 2), then A/C depending on scores
        XCTAssertEqual(aggregated.first?.id, b.id)
    }
    
    func testUpsertContributionUpdatesAggregation() {
        let a = RankleItem(title: "A")
        let b = RankleItem(title: "B")
        let c = RankleItem(title: "C")
        let vm = ListsViewModel()
        vm.createList(name: "Collab", items: [a.title, b.title, c.title], isCollaborative: true)
        guard var list = vm.lists.last else { return XCTFail("Missing list") }
        list.items = [a, b, c]
        vm.replaceList(list)
        let uid = UUID()
        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: uid, ranking: [a.id, b.id, c.id]))
        vm.upsertContribution(listId: list.id, ranking: CollaboratorRanking(userId: UUID(), ranking: [b.id, c.id, a.id]))
        let updated = vm.lists.last!
        XCTAssertTrue(updated.isCollaborative)
        XCTAssertEqual(updated.collaborators.count, 2)
        // Expect B likely first
        XCTAssertEqual(updated.items.first?.title, "B")
    }
}

