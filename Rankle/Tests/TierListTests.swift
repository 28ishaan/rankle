import XCTest
@testable import Rankle

/// Tests for tier list functionality, including edge cases and backward compatibility
final class TierListTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    
    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-tier-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(fileManager: .default, baseDirectoryURL: tempDir)
        viewModel = ListsViewModel(storage: storage)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Tier List Creation Tests
    
    func testCreateTierList() {
        viewModel.createTierList(name: "Games Tier List", items: ["Game 1", "Game 2", "Game 3"], color: .blue)
        
        XCTAssertEqual(viewModel.lists.count, 1, "Should have one list")
        let list = viewModel.lists.first!
        XCTAssertEqual(list.name, "Games Tier List")
        XCTAssertEqual(list.listType, .tier, "List type should be tier")
        XCTAssertEqual(list.items.count, 3, "Should have 3 items")
        XCTAssertFalse(list.isCollaborative, "Tier lists cannot be collaborative")
        XCTAssertTrue(list.tierAssignments.isEmpty, "New tier list should have no tier assignments")
    }
    
    func testCreateTierListWithItems() {
        let items = [
            RankleItem(title: "Item 1"),
            RankleItem(title: "Item 2"),
            RankleItem(title: "Item 3")
        ]
        viewModel.createTierListWithItems(name: "My Tier List", items: items, color: .green)
        
        let list = viewModel.lists.first!
        XCTAssertEqual(list.listType, .tier)
        XCTAssertEqual(list.items.count, 3)
        XCTAssertTrue(list.unassignedItems.count == 3, "All items should be unassigned initially")
    }
    
    func testTierListCannotBeCollaborative() {
        // Even if isCollaborative is passed as true, tier lists should not be collaborative
        viewModel.createTierList(name: "Test", items: ["Item"], color: .red, isCollaborative: true)
        
        let list = viewModel.lists.first!
        XCTAssertEqual(list.listType, .tier)
        XCTAssertFalse(list.isCollaborative, "Tier lists should never be collaborative")
    }
    
    // MARK: - Tier Assignment Tests
    
    func testAssignItemToTier() {
        let items = [
            RankleItem(title: "Item 1"),
            RankleItem(title: "Item 2"),
            RankleItem(title: "Item 3")
        ]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .cyan)
        var list = viewModel.lists.first!
        
        // Assign item 1 to S tier
        list.tierAssignments[items[0].id] = Tier.s.rawValue
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.itemsInTier(.s).count, 1, "Should have 1 item in S tier")
        XCTAssertEqual(updated.itemsInTier(.s).first?.id, items[0].id)
        XCTAssertEqual(updated.unassignedItems.count, 2, "Should have 2 unassigned items")
    }
    
    func testAssignMultipleItemsToSameTier() {
        let items = (0..<5).map { RankleItem(title: "Item \($0)") }
        viewModel.createTierListWithItems(name: "Test", items: items, color: .purple)
        var list = viewModel.lists.first!
        
        // Assign first 3 items to A tier
        for i in 0..<3 {
            list.tierAssignments[items[i].id] = Tier.a.rawValue
        }
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.itemsInTier(.a).count, 3, "Should have 3 items in A tier")
        XCTAssertEqual(updated.unassignedItems.count, 2, "Should have 2 unassigned items")
    }
    
    func testMoveItemBetweenTiers() {
        let items = [RankleItem(title: "Item 1"), RankleItem(title: "Item 2")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .orange)
        var list = viewModel.lists.first!
        
        // Assign to S tier
        list.tierAssignments[items[0].id] = Tier.s.rawValue
        viewModel.replaceList(list)
        
        var updated = viewModel.lists.first!
        XCTAssertEqual(updated.itemsInTier(.s).count, 1)
        
        // Move to F tier
        updated.tierAssignments[items[0].id] = Tier.f.rawValue
        viewModel.replaceList(updated)
        
        let final = viewModel.lists.first!
        XCTAssertEqual(final.itemsInTier(.s).count, 0, "S tier should be empty")
        XCTAssertEqual(final.itemsInTier(.f).count, 1, "F tier should have 1 item")
    }
    
    func testRemoveItemFromTier() {
        let items = [RankleItem(title: "Item 1")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .yellow)
        var list = viewModel.lists.first!
        
        // Assign to B tier
        list.tierAssignments[items[0].id] = Tier.b.rawValue
        viewModel.replaceList(list)
        
        var updated = viewModel.lists.first!
        XCTAssertEqual(updated.itemsInTier(.b).count, 1)
        
        // Remove assignment (make unassigned)
        updated.tierAssignments.removeValue(forKey: items[0].id)
        viewModel.replaceList(updated)
        
        let final = viewModel.lists.first!
        XCTAssertEqual(final.itemsInTier(.b).count, 0, "B tier should be empty")
        XCTAssertEqual(final.unassignedItems.count, 1, "Should have 1 unassigned item")
    }
    
    func testAllTiersEmptyInitially() {
        let items = [RankleItem(title: "Item 1")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .pink)
        let list = viewModel.lists.first!
        
        for tier in Tier.allCases {
            XCTAssertEqual(list.itemsInTier(tier).count, 0, "\(tier.rawValue) tier should be empty")
        }
        XCTAssertEqual(list.unassignedItems.count, 1, "All items should be unassigned")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTierList() {
        viewModel.createTierList(name: "Empty", items: [], color: .gray)
        let list = viewModel.lists.first!
        
        XCTAssertEqual(list.items.count, 0)
        XCTAssertEqual(list.unassignedItems.count, 0)
        for tier in Tier.allCases {
            XCTAssertEqual(list.itemsInTier(tier).count, 0)
        }
    }
    
    func testTierListWithManyItems() {
        let items = (0..<50).map { RankleItem(title: "Item \($0)") }
        viewModel.createTierListWithItems(name: "Large List", items: items, color: .red)
        var list = viewModel.lists.first!
        
        // Assign items to different tiers
        for (index, item) in items.enumerated() {
            let tierIndex = index % Tier.allCases.count
            list.tierAssignments[item.id] = Tier.allCases[tierIndex].rawValue
        }
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        // Each tier should have approximately 50/6 items
        let expectedPerTier = 50 / Tier.allCases.count
        for tier in Tier.allCases {
            let count = updated.itemsInTier(tier).count
            XCTAssertGreaterThanOrEqual(count, expectedPerTier - 1, "Tier \(tier.rawValue) should have items")
            XCTAssertLessThanOrEqual(count, expectedPerTier + 1)
        }
    }
    
    func testItemsInTierReturnsEmptyForRegularList() {
        // Regular lists should return empty for tier queries
        viewModel.createList(name: "Regular", items: ["Item 1", "Item 2"], color: .blue)
        let list = viewModel.lists.first!
        
        XCTAssertEqual(list.listType, .regular)
        for tier in Tier.allCases {
            XCTAssertEqual(list.itemsInTier(tier).count, 0, "Regular lists should return empty for tier queries")
        }
        XCTAssertEqual(list.unassignedItems.count, 0, "Regular lists should have no unassigned items")
    }
    
    func testUnassignedItemsForRegularList() {
        viewModel.createList(name: "Regular", items: ["Item"], color: .cyan)
        let list = viewModel.lists.first!
        
        XCTAssertEqual(list.unassignedItems.count, 0, "Regular lists should have no unassigned items concept")
    }
    
    func testTierAssignmentWithInvalidItemID() {
        let items = [RankleItem(title: "Item 1")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .green)
        var list = viewModel.lists.first!
        
        // Assign non-existent item ID
        let fakeID = UUID()
        list.tierAssignments[fakeID] = Tier.s.rawValue
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.itemsInTier(.s).count, 0, "Should not find items with invalid IDs")
    }
    
    func testAllTiersHaveCorrectOrder() {
        // Verify tier order: S, A, B, C, D, F
        let tiers = Tier.allCases
        XCTAssertEqual(tiers.count, 6, "Should have 6 tiers")
        XCTAssertEqual(tiers[0], .s, "First tier should be S")
        XCTAssertEqual(tiers[1], .a, "Second tier should be A")
        XCTAssertEqual(tiers[2], .b, "Third tier should be B")
        XCTAssertEqual(tiers[3], .c, "Fourth tier should be C")
        XCTAssertEqual(tiers[4], .d, "Fifth tier should be D")
        XCTAssertEqual(tiers[5], .f, "Sixth tier should be F")
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testBackwardCompatibilityRegularListDefaults() {
        // Create a list without listType (simulating old data)
        let items = [RankleItem(title: "Item 1")]
        var list = RankleList(name: "Old List", items: items)
        // Don't set listType - it should default to .regular
        
        XCTAssertEqual(list.listType, .regular, "Lists without listType should default to regular")
        XCTAssertTrue(list.tierAssignments.isEmpty, "Regular lists should have empty tier assignments")
    }
    
    func testBackwardCompatibilityLoadOldList() {
        // Create a list and save it
        viewModel.createList(name: "Old List", items: ["Item 1", "Item 2"], color: .blue)
        let originalList = viewModel.lists.first!
        
        // Manually encode and decode to simulate old format (without listType)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        guard let data = try? encoder.encode([originalList]) else {
            XCTFail("Failed to encode list")
            return
        }
        
        // Decode as if it's old data (listType will default to .regular)
        guard let decodedLists = try? decoder.decode([RankleList].self, from: data) else {
            XCTFail("Failed to decode list")
            return
        }
        
        let decodedList = decodedLists.first!
        XCTAssertEqual(decodedList.listType, .regular, "Decoded list should default to regular")
        XCTAssertEqual(decodedList.items.count, 2, "Items should be preserved")
        XCTAssertEqual(decodedList.name, "Old List", "Name should be preserved")
    }
    
    func testBackwardCompatibilityExistingListsNotDeleted() {
        // Create multiple regular lists
        viewModel.createList(name: "List 1", items: ["A", "B"], color: .red)
        viewModel.createList(name: "List 2", items: ["C", "D"], color: .green)
        viewModel.createList(name: "List 3", items: ["E", "F"], color: .blue)
        
        XCTAssertEqual(viewModel.lists.count, 3, "Should have 3 regular lists")
        
        // Create tier lists
        viewModel.createTierList(name: "Tier 1", items: ["X", "Y"], color: .purple)
        viewModel.createTierList(name: "Tier 2", items: ["Z"], color: .orange)
        
        XCTAssertEqual(viewModel.lists.count, 5, "Should have 5 total lists")
        
        // Verify regular lists still exist
        let regularLists = viewModel.lists.filter { $0.listType == .regular }
        XCTAssertEqual(regularLists.count, 3, "Should still have 3 regular lists")
        
        // Verify tier lists exist
        let tierLists = viewModel.lists.filter { $0.listType == .tier }
        XCTAssertEqual(tierLists.count, 2, "Should have 2 tier lists")
    }
    
    func testBackwardCompatibilityStoragePersistence() {
        // Create mix of regular and tier lists
        viewModel.createList(name: "Regular", items: ["Item"], color: .cyan)
        viewModel.createTierList(name: "Tier", items: ["Tier Item"], color: .red)
        
        // Create new view model (simulates app restart)
        let newViewModel = ListsViewModel(storage: storage)
        
        XCTAssertEqual(newViewModel.lists.count, 2, "Should load both lists")
        let regular = newViewModel.lists.first { $0.name == "Regular" }!
        let tier = newViewModel.lists.first { $0.name == "Tier" }!
        
        XCTAssertEqual(regular.listType, .regular, "Regular list should be preserved")
        XCTAssertEqual(tier.listType, .tier, "Tier list should be preserved")
        XCTAssertEqual(regular.items.count, 1, "Regular list items should be preserved")
        XCTAssertEqual(tier.items.count, 1, "Tier list items should be preserved")
    }
    
    func testBackwardCompatibilityTierAssignmentsPreserved() {
        let items = [RankleItem(title: "Item 1"), RankleItem(title: "Item 2")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .yellow)
        var list = viewModel.lists.first!
        
        // Assign items to tiers
        list.tierAssignments[items[0].id] = Tier.s.rawValue
        list.tierAssignments[items[1].id] = Tier.a.rawValue
        viewModel.replaceList(list)
        
        // Simulate app restart
        let newViewModel = ListsViewModel(storage: storage)
        let loaded = newViewModel.lists.first!
        
        XCTAssertEqual(loaded.itemsInTier(.s).count, 1, "S tier assignment should be preserved")
        XCTAssertEqual(loaded.itemsInTier(.a).count, 1, "A tier assignment should be preserved")
        XCTAssertEqual(loaded.unassignedItems.count, 0, "No items should be unassigned")
    }
    
    // MARK: - Integration Tests
    
    func testTierListAndRegularListCoexist() {
        // Create both types of lists
        viewModel.createList(name: "Regular Ranking", items: ["A", "B", "C"], color: .blue)
        viewModel.createTierList(name: "Tier Ranking", items: ["X", "Y", "Z"], color: .red)
        
        XCTAssertEqual(viewModel.lists.count, 2)
        
        let regular = viewModel.lists.first { $0.name == "Regular Ranking" }!
        let tier = viewModel.lists.first { $0.name == "Tier Ranking" }!
        
        XCTAssertEqual(regular.listType, .regular)
        XCTAssertEqual(tier.listType, .tier)
        XCTAssertEqual(regular.items.count, 3)
        XCTAssertEqual(tier.items.count, 3)
        XCTAssertTrue(tier.unassignedItems.count == 3, "Tier list items should be unassigned")
    }
    
    func testTierListItemsCanBeAdded() {
        viewModel.createTierList(name: "Test", items: ["Item 1"], color: .green)
        var list = viewModel.lists.first!
        
        // Add new item
        list.items.append(RankleItem(title: "Item 2"))
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.items.count, 2)
        XCTAssertEqual(updated.unassignedItems.count, 2, "New items should be unassigned")
    }
    
    func testTierListItemsCanBeRemoved() {
        let items = [RankleItem(title: "Item 1"), RankleItem(title: "Item 2")]
        viewModel.createTierListWithItems(name: "Test", items: items, color: .purple)
        var list = viewModel.lists.first!
        
        // Assign both to tiers
        list.tierAssignments[items[0].id] = Tier.s.rawValue
        list.tierAssignments[items[1].id] = Tier.a.rawValue
        viewModel.replaceList(list)
        
        // Remove one item
        list.items.removeAll { $0.id == items[0].id }
        list.tierAssignments.removeValue(forKey: items[0].id) // Clean up orphaned assignment
        viewModel.replaceList(list)
        
        let updated = viewModel.lists.first!
        XCTAssertEqual(updated.items.count, 1)
        XCTAssertEqual(updated.itemsInTier(.s).count, 0, "Removed item should not be in S tier")
        XCTAssertEqual(updated.itemsInTier(.a).count, 1, "Remaining item should be in A tier")
    }
    
    // MARK: - Tier Model Tests
    
    func testTierDisplayNames() {
        XCTAssertEqual(Tier.s.displayName, "S")
        XCTAssertEqual(Tier.a.displayName, "A")
        XCTAssertEqual(Tier.b.displayName, "B")
        XCTAssertEqual(Tier.c.displayName, "C")
        XCTAssertEqual(Tier.d.displayName, "D")
        XCTAssertEqual(Tier.f.displayName, "F")
    }
    
    func testTierColors() {
        // Verify each tier has a distinct color
        let colors = Set(Tier.allCases.map { $0.color })
        XCTAssertEqual(colors.count, Tier.allCases.count, "Each tier should have a unique color")
    }
    
    func testListTypeEnum() {
        XCTAssertEqual(ListType.regular.rawValue, "regular")
        XCTAssertEqual(ListType.tier.rawValue, "tier")
    }
}

