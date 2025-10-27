import Foundation

final class StorageService {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let listsFileURL: URL
    private let mediaDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.listsFileURL = directoryURL.appendingPathComponent("rankle_lists.json")
        self.mediaDirectoryURL = directoryURL.appendingPathComponent("Media", isDirectory: true)
        try? fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
    }

    func loadLists() -> [RankleList] {
        guard fileManager.fileExists(atPath: listsFileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: listsFileURL)
            let lists = try JSONDecoder().decode([RankleList].self, from: data)
            return lists
        } catch {
            return []
        }
    }

    func saveLists(_ lists: [RankleList]) {
        do {
            let data = try JSONEncoder().encode(lists)
            try data.write(to: listsFileURL, options: [.atomic])
        } catch {
            // In MVP, ignore write errors
        }
    }

    func urlForMedia(filename: String) -> URL { mediaDirectoryURL.appendingPathComponent(filename) }

    func saveMedia(data: Data, fileExtension: String) throws -> String {
        let filename = UUID().uuidString + "." + fileExtension
        let url = urlForMedia(filename: filename)
        try data.write(to: url, options: [.atomic])
        return filename
    }
    
    func loadMedia(filename: String) -> Data? {
        let url = urlForMedia(filename: filename)
        return try? Data(contentsOf: url)
    }
}
