import XCTest
@testable import Rankle

final class StorageServiceTests: XCTestCase {
    private var tempDir: URL! = nil
    private var storage: StorageService! = nil

    override func setUp() {
        super.setUp()
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rankle-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        tempDir = base
        storage = StorageService(fileManager: .default, baseDirectoryURL: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        storage = nil
        super.tearDown()
    }

    func testSaveAndLoadLists() throws {
        let lists = [
            RankleList(name: "Movies", items: [RankleItem(title: "Inception"), RankleItem(title: "Interstellar")]),
            RankleList(name: "Foods", items: [RankleItem(title: "Pizza")])
        ]

        storage.saveLists(lists)
        let loaded = storage.loadLists()

        XCTAssertEqual(loaded.count, lists.count)
        XCTAssertEqual(loaded.first?.name, "Movies")
        XCTAssertEqual(loaded.first?.items.count, 2)
    }

    func testBackupRotationOnSave() throws {
        // Initial save
        let first = [RankleList(name: "One", items: [RankleItem(title: "A")])]
        storage.saveLists(first)

        // Second save triggers backup rotation
        let second = [RankleList(name: "Two", items: [RankleItem(title: "B")])]
        storage.saveLists(second)

        // Primary should be latest
        let loaded = storage.loadLists()
        XCTAssertEqual(loaded.first?.name, "Two")

        // Backup mirrors the latest good state
        let backupURL = tempDir.appendingPathComponent("rankle_lists.backup.json")
        let backupData = try Data(contentsOf: backupURL)
        let backupLists = try JSONDecoder().decode([RankleList].self, from: backupData)
        XCTAssertEqual(backupLists.first?.name, "Two")
    }

    func testRestoreFromBackupWhenPrimaryCorrupted() throws {
        let original = [RankleList(name: "KeepMe", items: [RankleItem(title: "X")])]
        storage.saveLists(original)

        // Corrupt primary file after a successful save and backup
        let primaryURL = tempDir.appendingPathComponent("rankle_lists.json")
        try "corrupted".data(using: .utf8)!.write(to: primaryURL, options: [.atomic])

        // Should fall back to backup automatically
        let loaded = storage.loadLists()
        XCTAssertEqual(loaded.first?.name, "KeepMe")
    }

    func testMigrateFromLegacyFilenameInDocuments() throws {
        // Simulate a legacy filename in the same directory
        let legacyURL = tempDir.appendingPathComponent("lists.json")
        let legacyLists = [RankleList(name: "Legacy", items: [RankleItem(title: "Old")])]
        let data = try JSONEncoder().encode(legacyLists)
        try data.write(to: legacyURL, options: [.atomic])

        // Recreate storage to run migration in init()
        storage = StorageService(fileManager: .default, baseDirectoryURL: tempDir)
        let loaded = storage.loadLists()

        XCTAssertEqual(loaded.first?.name, "Legacy")

        // Ensure migration promoted legacy to primary path
        let primaryURL = tempDir.appendingPathComponent("rankle_lists.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: primaryURL.path))
    }

    func testLoadReturnsEmptyWhenNoFiles() {
        let loaded = storage.loadLists()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testMigrationDoesNotOverwriteValidPrimary() throws {
        // Write valid primary
        let primaryLists = [RankleList(name: "Primary", items: [RankleItem(title: "P")])]
        let primaryURL = tempDir.appendingPathComponent("rankle_lists.json")
        let primaryData = try JSONEncoder().encode(primaryLists)
        try primaryData.write(to: primaryURL, options: [.atomic])

        // Write also a legacy file; migration should not override since primary exists
        let legacyURL = tempDir.appendingPathComponent("lists.json")
        let legacyLists = [RankleList(name: "Legacy", items: [RankleItem(title: "L")])]
        let legacyData = try JSONEncoder().encode(legacyLists)
        try legacyData.write(to: legacyURL, options: [.atomic])

        // Recreate storage (would attempt migration in init but should early return)
        storage = StorageService(fileManager: .default, baseDirectoryURL: tempDir)
        let loaded = storage.loadLists()

        XCTAssertEqual(loaded.first?.name, "Primary")
    }
}


