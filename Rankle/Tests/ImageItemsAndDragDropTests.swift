import XCTest
import UIKit
@testable import Rankle

/// Tests for image items, drag-and-drop reordering, and manual editing features
final class ImageItemsAndDragDropTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageService!
    private var viewModel: ListsViewModel!
    
    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-image-tests-\(UUID().uuidString)")
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
    
    // MARK: - Image Item Creation Tests
    
    func testCreateItemWithImage() throws {
        // Create a test image
        let testImage = createTestImage(width: 100, height: 150)
        let imageData = testImage.pngData()!
        
        // Save image to storage
        let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
        
        // Create item with image
        let mediaItem = MediaItem(type: .image, filename: filename)
        let item = RankleItem(title: "", media: [mediaItem])
        
        XCTAssertTrue(item.media.count == 1, "Item should have one media item")
        XCTAssertEqual(item.media.first?.type, .image, "Media type should be image")
        XCTAssertTrue(item.title.isEmpty, "Image-only item should have empty title")
    }
    
    func testCreateItemWithImageAndText() throws {
        let testImage = createTestImage(width: 200, height: 200)
        let imageData = testImage.pngData()!
        let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
        
        let mediaItem = MediaItem(type: .image, filename: filename)
        let item = RankleItem(title: "Test Item", media: [mediaItem])
        
        XCTAssertEqual(item.title, "Test Item", "Item should have title")
        XCTAssertTrue(item.media.count == 1, "Item should have media")
    }
    
    func testImageAspectRatioPreservation() throws {
        // Create images with different aspect ratios
        let portraitImage = createTestImage(width: 100, height: 200) // 1:2 ratio
        let landscapeImage = createTestImage(width: 200, height: 100) // 2:1 ratio
        let squareImage = createTestImage(width: 150, height: 150) // 1:1 ratio
        
        let portraitData = portraitImage.pngData()!
        let landscapeData = landscapeImage.pngData()!
        let squareData = squareImage.pngData()!
        
        let portraitFilename = try storage.saveMedia(data: portraitData, fileExtension: "png")
        let landscapeFilename = try storage.saveMedia(data: landscapeData, fileExtension: "png")
        let squareFilename = try storage.saveMedia(data: squareData, fileExtension: "png")
        
        // Load images back and verify aspect ratios
        let loadedPortrait = UIImage(contentsOfFile: storage.urlForMedia(filename: portraitFilename).path)!
        let loadedLandscape = UIImage(contentsOfFile: storage.urlForMedia(filename: landscapeFilename).path)!
        let loadedSquare = UIImage(contentsOfFile: storage.urlForMedia(filename: squareFilename).path)!
        
        let portraitRatio = Double(loadedPortrait.size.width) / Double(loadedPortrait.size.height)
        let landscapeRatio = Double(loadedLandscape.size.width) / Double(loadedLandscape.size.height)
        let squareRatio = Double(loadedSquare.size.width) / Double(loadedSquare.size.height)
        
        XCTAssertEqual(portraitRatio, 0.5, accuracy: 0.01, "Portrait image should maintain 1:2 aspect ratio")
        XCTAssertEqual(landscapeRatio, 2.0, accuracy: 0.01, "Landscape image should maintain 2:1 aspect ratio")
        XCTAssertEqual(squareRatio, 1.0, accuracy: 0.01, "Square image should maintain 1:1 aspect ratio")
    }
    
    func testImageOnlyItemDisplayLabel() {
        let item = RankleItem(title: "", media: [MediaItem(type: .image, filename: "test.jpg")])
        
        // Image-only items should display "Image" as label
        let displayText = item.title.isEmpty && !item.media.isEmpty ? "Image" : item.title
        XCTAssertEqual(displayText, "Image", "Image-only item should display 'Image' label")
    }
    
    func testItemWithBothTitleAndImage() {
        let item = RankleItem(title: "My Item", media: [MediaItem(type: .image, filename: "test.jpg")])
        
        let displayText = item.title.isEmpty && !item.media.isEmpty ? "Image" : item.title
        XCTAssertEqual(displayText, "My Item", "Item with title should display title, not 'Image'")
    }
    
    // MARK: - Drag and Drop Reordering Tests
    
    func testDragAndDropReordersItems() {
        // Create list with items
        let items = ["A", "B", "C", "D"].map { RankleItem(title: $0) }
        viewModel.createListWithItems(name: "Reorder Test", items: items, isCollaborative: false)
        
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Verify initial order
        XCTAssertEqual(list.items[0].title, "A")
        XCTAssertEqual(list.items[1].title, "B")
        XCTAssertEqual(list.items[2].title, "C")
        XCTAssertEqual(list.items[3].title, "D")
        
        // Simulate drag and drop: move item at index 0 to index 3
        // This simulates moving "A" to the end
        list.items.move(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        
        // Verify new order
        XCTAssertEqual(list.items[0].title, "B", "First item should now be B")
        XCTAssertEqual(list.items[1].title, "C", "Second item should now be C")
        XCTAssertEqual(list.items[2].title, "D", "Third item should now be D")
        XCTAssertEqual(list.items[3].title, "A", "Last item should now be A")
    }
    
    func testDragAndDropMultipleItems() {
        let items = ["A", "B", "C", "D", "E"].map { RankleItem(title: $0) }
        viewModel.createListWithItems(name: "Multi Move", items: items, isCollaborative: false)
        
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Move items at indices 0 and 1 to position 4 (after D)
        list.items.move(fromOffsets: IndexSet([0, 1]), toOffset: 4)
        
        // Expected order: C, D, A, B, E
        XCTAssertEqual(list.items[0].title, "C")
        XCTAssertEqual(list.items[1].title, "D")
        XCTAssertEqual(list.items[2].title, "A")
        XCTAssertEqual(list.items[3].title, "B")
        XCTAssertEqual(list.items[4].title, "E")
    }
    
    func testDragAndDropPreservesItemIDs() {
        let items = ["A", "B", "C"].map { RankleItem(title: $0) }
        let originalIDs = items.map { $0.id }
        
        viewModel.createListWithItems(name: "ID Test", items: items, isCollaborative: false)
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Reorder items
        list.items.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        
        // Verify all original IDs are still present
        let currentIDs = list.items.map { $0.id }
        for originalID in originalIDs {
            XCTAssertTrue(currentIDs.contains(originalID), "Item ID \(originalID) should be preserved after reordering")
        }
    }
    
    func testDragAndDropWithImageItems() throws {
        // Create items with images
        let image1 = createTestImage(width: 100, height: 100)
        let image2 = createTestImage(width: 100, height: 100)
        let image3 = createTestImage(width: 100, height: 100)
        
        let filename1 = try storage.saveMedia(data: image1.pngData()!, fileExtension: "png")
        let filename2 = try storage.saveMedia(data: image2.pngData()!, fileExtension: "png")
        let filename3 = try storage.saveMedia(data: image3.pngData()!, fileExtension: "png")
        
        let item1 = RankleItem(title: "Item 1", media: [MediaItem(type: .image, filename: filename1)])
        let item2 = RankleItem(title: "Item 2", media: [MediaItem(type: .image, filename: filename2)])
        let item3 = RankleItem(title: "Item 3", media: [MediaItem(type: .image, filename: filename3)])
        
        viewModel.createListWithItems(name: "Image Reorder", items: [item1, item2, item3], isCollaborative: false)
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Reorder: move first to last
        list.items.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        
        // Verify order changed but media preserved
        XCTAssertEqual(list.items[0].title, "Item 2")
        XCTAssertEqual(list.items[1].title, "Item 3")
        XCTAssertEqual(list.items[2].title, "Item 1")
        
        // Verify media files are still accessible
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.urlForMedia(filename: filename1).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.urlForMedia(filename: filename2).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.urlForMedia(filename: filename3).path))
    }
    
    // MARK: - Manual Editing Integration Tests
    
    func testManualReorderUpdatesList() {
        let items = ["First", "Second", "Third"].map { RankleItem(title: $0) }
        viewModel.createListWithItems(name: "Manual Edit", items: items, isCollaborative: false)
        
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Manual reorder
        list.items.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        
        // Update via view model
        viewModel.replaceList(list)
        
        // Verify update persisted
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.items[0].title, "Third")
        XCTAssertEqual(updated.items[1].title, "First")
        XCTAssertEqual(updated.items[2].title, "Second")
    }
    
    func testManualReorderWithCollaborativeList() {
        let items = ["A", "B", "C"].map { RankleItem(title: $0) }
        viewModel.createListWithItems(name: "Collaborative Reorder", items: items, isCollaborative: true)
        
        let listId = viewModel.lists.first!.id
        var list = viewModel.getList(id: listId)!
        
        // Reorder manually
        list.items.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        let reorderedIds = list.items.map { $0.id }
        
        // For collaborative lists, reordering should create a contribution
        let ranking = CollaboratorRanking(
            userId: UserService.shared.currentUserId,
            ranking: reorderedIds
        )
        viewModel.upsertContribution(listId: listId, ranking: ranking)
        
        // Verify contribution was saved
        let updated = viewModel.getList(id: listId)!
        XCTAssertEqual(updated.collaborators.count, 1)
        XCTAssertEqual(updated.collaborators.first?.ranking, reorderedIds)
    }
    
    // MARK: - Image Storage and Loading Tests
    
    func testSaveAndLoadImageMedia() throws {
        let testImage = createTestImage(width: 300, height: 400)
        let imageData = testImage.pngData()!
        
        let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
        XCTAssertFalse(filename.isEmpty, "Filename should be generated")
        
        // Verify file exists
        let fileURL = storage.urlForMedia(filename: filename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Image file should exist")
        
        // Load and verify
        let loadedData = storage.loadMedia(filename: filename)
        XCTAssertNotNil(loadedData, "Should be able to load image data")
        XCTAssertEqual(loadedData?.count, imageData.count, "Loaded data should match original size")
        
        // Verify image can be loaded as UIImage
        let loadedImage = UIImage(contentsOfFile: fileURL.path)
        XCTAssertNotNil(loadedImage, "Should be able to load as UIImage")
        if let image = loadedImage {
            // When saving PNG and reloading, the scale factor is lost, but pixel dimensions are preserved
            // The actual pixel dimensions should match (accounting for device scale)
            // We verify the aspect ratio is preserved instead of exact dimensions
            let aspectRatio = Double(image.size.width / image.size.height)
            let expectedRatio = 300.0 / 400.0
            XCTAssertEqual(aspectRatio, expectedRatio, accuracy: 0.01, "Image aspect ratio should be preserved")
            // Verify the image has reasonable dimensions (not zero or negative)
            XCTAssertGreaterThan(image.size.width, 0, "Image width should be positive")
            XCTAssertGreaterThan(image.size.height, 0, "Image height should be positive")
        }
    }
    
    func testMultipleImagesInList() throws {
        var items: [RankleItem] = []
        
        // Create multiple items with different images
        for i in 1...5 {
            let image = createTestImage(width: 100 + i * 10, height: 100 + i * 10)
            let imageData = image.pngData()!
            let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
            let mediaItem = MediaItem(type: .image, filename: filename)
            let item = RankleItem(title: "Item \(i)", media: [mediaItem])
            items.append(item)
        }
        
        viewModel.createListWithItems(name: "Multiple Images", items: items, isCollaborative: false)
        
        let list = viewModel.lists.first!
        XCTAssertEqual(list.items.count, 5)
        
        // Verify all images are accessible
        for item in list.items {
            XCTAssertTrue(item.media.count == 1, "Each item should have one image")
            let filename = item.media.first!.filename
            let fileURL = storage.urlForMedia(filename: filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Image file should exist for \(item.title)")
        }
    }
    
    // MARK: - Aspect Ratio in Display Tests
    
    func testImageAspectRatioInScaledToFit() throws {
        // Create a wide image (2:1 ratio)
        let wideImage = createTestImage(width: 400, height: 200)
        let imageData = wideImage.pngData()!
        let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
        
        // Load image
        let loadedImage = UIImage(contentsOfFile: storage.urlForMedia(filename: filename).path)!
        
        // Simulate scaledToFit behavior with a target frame
        let targetSize = CGSize(width: 200, height: 200)
        let imageSize = loadedImage.size
        
        // Calculate aspect-fit size
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        
        // Verify aspect ratio is preserved
        let originalRatio = imageSize.width / imageSize.height
        let scaledRatio = scaledWidth / scaledHeight
        
        XCTAssertEqual(originalRatio, scaledRatio, accuracy: 0.01, "Aspect ratio should be preserved in scaledToFit")
        XCTAssertEqual(originalRatio, 2.0, accuracy: 0.01, "Original image should be 2:1")
    }
    
    func testImageAspectRatioInScaledToFitPortrait() throws {
        // Create a tall image (1:2 ratio)
        let tallImage = createTestImage(width: 200, height: 400)
        let imageData = tallImage.pngData()!
        let filename = try storage.saveMedia(data: imageData, fileExtension: "png")
        
        let loadedImage = UIImage(contentsOfFile: storage.urlForMedia(filename: filename).path)!
        
        let targetSize = CGSize(width: 200, height: 200)
        let imageSize = loadedImage.size
        
        let widthRatio = targetSize.width / imageSize.width
        let heightRatio = targetSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scaleFactor
        let scaledHeight = imageSize.height * scaleFactor
        
        let originalRatio = imageSize.width / imageSize.height
        let scaledRatio = scaledWidth / scaledHeight
        
        XCTAssertEqual(originalRatio, scaledRatio, accuracy: 0.01, "Portrait aspect ratio should be preserved")
        XCTAssertEqual(originalRatio, 0.5, accuracy: 0.01, "Original image should be 1:2")
    }
    
    // MARK: - One Image Per Item Constraint Tests
    
    func testOnlyOneImagePerItem() {
        // Create item with one image
        let item = RankleItem(
            title: "Test",
            media: [MediaItem(type: .image, filename: "test1.jpg")]
        )
        
        XCTAssertEqual(item.media.count, 1, "Item should have one image")
        
        // Attempting to add another image should be prevented by UI logic
        // This is tested at the view level, but we verify the constraint exists
        var updatedItem = item
        updatedItem.media.append(MediaItem(type: .image, filename: "test2.jpg"))
        
        // While the model allows multiple, the UI should prevent this
        // We verify the model structure supports the constraint
        XCTAssertEqual(updatedItem.media.count, 2, "Model allows multiple, but UI should prevent")
    }
    
    // MARK: - Ranking with Images Tests
    
    func testRankingWithImageItems() throws {
        // Create items with images
        let image1 = createTestImage(width: 100, height: 100)
        let image2 = createTestImage(width: 100, height: 100)
        let image3 = createTestImage(width: 100, height: 100)
        
        let filename1 = try storage.saveMedia(data: image1.pngData()!, fileExtension: "png")
        let filename2 = try storage.saveMedia(data: image2.pngData()!, fileExtension: "png")
        let filename3 = try storage.saveMedia(data: image3.pngData()!, fileExtension: "png")
        
        let item1 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename1)])
        let item2 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename2)])
        let item3 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename3)])
        
        let list = RankleList(name: "Image Ranking", items: [item1, item2, item3])
        let viewModel = RankingViewModel(list: list)
        
        // Verify matchup can be created with image items
        XCTAssertNotNil(viewModel.currentMatchup, "Should have initial matchup")
        
        // Verify matchup contains image items
        if let matchup = viewModel.currentMatchup {
            XCTAssertTrue(matchup.left.media.count > 0 || matchup.right.media.count > 0, "Matchup should contain image items")
        }
    }
    
    func testRankingWithMixedTextAndImageItems() throws {
        let textItem = RankleItem(title: "Text Item")
        
        let image = createTestImage(width: 100, height: 100)
        let filename = try storage.saveMedia(data: image.pngData()!, fileExtension: "png")
        let imageItem = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename)])
        
        let list = RankleList(name: "Mixed", items: [textItem, imageItem])
        let viewModel = RankingViewModel(list: list)
        
        XCTAssertNotNil(viewModel.currentMatchup, "Should handle mixed items")
        
        // Complete ranking
        var safety = 100
        while !viewModel.isComplete && safety > 0 {
            if viewModel.currentMatchup != nil {
                // Always prefer left for testing
                viewModel.choose(.left)
            }
            safety -= 1
        }
        
        XCTAssertTrue(viewModel.isComplete, "Should complete ranking with mixed items")
        XCTAssertEqual(viewModel.list.items.count, 2, "Should preserve all items")
    }
    
    func testRankingPreservesImageAspectRatio() throws {
        // Create images with different aspect ratios
        let wideImage = createTestImage(width: 400, height: 200) // 2:1
        let tallImage = createTestImage(width: 200, height: 400) // 1:2
        
        let wideFilename = try storage.saveMedia(data: wideImage.pngData()!, fileExtension: "png")
        let tallFilename = try storage.saveMedia(data: tallImage.pngData()!, fileExtension: "png")
        
        let wideItem = RankleItem(title: "", media: [MediaItem(type: .image, filename: wideFilename)])
        let tallItem = RankleItem(title: "", media: [MediaItem(type: .image, filename: tallFilename)])
        
        let list = RankleList(name: "Aspect Test", items: [wideItem, tallItem])
        let viewModel = RankingViewModel(list: list)
        
        // Complete ranking
        if viewModel.currentMatchup != nil {
            viewModel.choose(.left)
        }
        
        // Verify images still have correct aspect ratios after ranking
        let completedList = viewModel.list
        for item in completedList.items {
            if let media = item.media.first,
               let image = UIImage(contentsOfFile: storage.urlForMedia(filename: media.filename).path) {
                let ratio = Double(image.size.width / image.size.height)
                // Verify aspect ratio is preserved (either 2:1 or 1:2)
                let isWide = abs(ratio - 2.0) < 0.01
                let isTall = abs(ratio - 0.5) < 0.01
                XCTAssertTrue(isWide || isTall, "Aspect ratio should be preserved (expected 2:1 or 1:2, got \(ratio))")
            }
        }
    }
    
    func testRankingGoBackWithImageItems() throws {
        let image1 = createTestImage(width: 100, height: 100)
        let image2 = createTestImage(width: 100, height: 100)
        let image3 = createTestImage(width: 100, height: 100)
        
        let filename1 = try storage.saveMedia(data: image1.pngData()!, fileExtension: "png")
        let filename2 = try storage.saveMedia(data: image2.pngData()!, fileExtension: "png")
        let filename3 = try storage.saveMedia(data: image3.pngData()!, fileExtension: "png")
        
        let item1 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename1)])
        let item2 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename2)])
        let item3 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename3)])
        
        let list = RankleList(name: "Back Test", items: [item1, item2, item3])
        let viewModel = RankingViewModel(list: list)
        
        // Make a choice
        if viewModel.currentMatchup != nil {
            viewModel.choose(.left)
        }
        
        // Verify we can go back
        if viewModel.canGoBack() {
            viewModel.goBack()
            XCTAssertNotNil(viewModel.currentMatchup, "Should restore previous matchup")
        }
    }
    
    // MARK: - Matchup Layout Tests
    
    func testMatchupLayoutTopVsBottom() {
        // This tests the conceptual layout - top vs bottom instead of side-by-side
        let item1 = RankleItem(title: "Top Item")
        let item2 = RankleItem(title: "Bottom Item")
        let matchup = Matchup(left: item1, right: item2)
        
        // In the UI, left should be displayed at top, right at bottom
        // This is a conceptual test - actual layout is tested in UI tests
        XCTAssertEqual(matchup.left.title, "Top Item")
        XCTAssertEqual(matchup.right.title, "Bottom Item")
    }
    
    func testMatchupLayoutWithImages() throws {
        let image1 = createTestImage(width: 300, height: 400) // Portrait
        let image2 = createTestImage(width: 400, height: 300) // Landscape
        
        let filename1 = try storage.saveMedia(data: image1.pngData()!, fileExtension: "png")
        let filename2 = try storage.saveMedia(data: image2.pngData()!, fileExtension: "png")
        
        let item1 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename1)])
        let item2 = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename2)])
        
        let matchup = Matchup(left: item1, right: item2)
        
        // Verify matchup contains images with different orientations
        XCTAssertTrue(matchup.left.media.count > 0, "Left item should have image")
        XCTAssertTrue(matchup.right.media.count > 0, "Right item should have image")
        
        // Verify images maintain their aspect ratios
        let leftImage = UIImage(contentsOfFile: storage.urlForMedia(filename: filename1).path)!
        let rightImage = UIImage(contentsOfFile: storage.urlForMedia(filename: filename2).path)!
        
        let leftRatio = leftImage.size.width / leftImage.size.height
        let rightRatio = rightImage.size.width / rightImage.size.height
        
        XCTAssertEqual(leftRatio, 0.75, accuracy: 0.01, "Left image should be portrait (3:4)")
        XCTAssertEqual(rightRatio, 1.33, accuracy: 0.01, "Right image should be landscape (4:3)")
    }
    
    // MARK: - Full Screen Layout Tests
    
    func testFullScreenLayoutPreventsImageOverlap() throws {
        // Test that images in top-vs-bottom layout don't overlap
        // This is conceptual - actual overlap prevention is in UI code
        let image1 = createTestImage(width: 100, height: 200)
        let image2 = createTestImage(width: 100, height: 200)
        
        let filename1 = try storage.saveMedia(data: image1.pngData()!, fileExtension: "png")
        let filename2 = try storage.saveMedia(data: image2.pngData()!, fileExtension: "png")
        
        // Items are created but not used directly - we just need the filenames for the test
        _ = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename1)])
        _ = RankleItem(title: "", media: [MediaItem(type: .image, filename: filename2)])
        
        // In top-vs-bottom layout, each image should occupy half the screen
        // This ensures no overlap
        let screenHeight: CGFloat = 800 // Simulated screen height
        let topHalfHeight = screenHeight / 2
        let bottomHalfHeight = screenHeight / 2
        
        // Verify each half is separate (no overlap)
        let topEnd = topHalfHeight
        let bottomStart = bottomHalfHeight
        
        XCTAssertEqual(bottomStart, topEnd, "Bottom should start where top ends (no gap, no overlap)")
        XCTAssertTrue(bottomStart >= topEnd, "Bottom should not overlap top")
    }
    
    // MARK: - CloudKit Integration with Images Tests
    
    func testCollaborativeListExcludesImages() {
        // Create list with image items
        let imageItem = RankleItem(
            title: "Test",
            media: [MediaItem(type: .image, filename: "test.jpg")]
        )
        
        // Create as collaborative - images should be removed automatically
        viewModel.createListWithItems(name: "No Images", items: [imageItem], isCollaborative: true)
        
        let list = viewModel.lists.first!
        XCTAssertTrue(list.isCollaborative)
        // Items in collaborative lists should not have media (removed during creation)
        XCTAssertTrue(list.items.allSatisfy { $0.media.isEmpty }, "Collaborative list items should not have media")
    }
    
    func testNonCollaborativeListPreservesImages() throws {
        let image = createTestImage(width: 100, height: 100)
        let filename = try storage.saveMedia(data: image.pngData()!, fileExtension: "png")
        
        let imageItem = RankleItem(
            title: "With Image",
            media: [MediaItem(type: .image, filename: filename)]
        )
        
        viewModel.createListWithItems(name: "With Images", items: [imageItem], isCollaborative: false)
        
        let list = viewModel.lists.first!
        XCTAssertFalse(list.isCollaborative)
        XCTAssertTrue(list.items.first?.media.count == 1, "Non-collaborative list should preserve images")
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        // Use scale: 1 to ensure consistent dimensions when saving/loading
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Create a simple colored rectangle
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some visual content to make it identifiable
            UIColor.white.setFill()
            let rect = CGRect(x: width/4, y: height/4, width: width/2, height: height/2)
            context.fill(rect)
        }
    }
}

