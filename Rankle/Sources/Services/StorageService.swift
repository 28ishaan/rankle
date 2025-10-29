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

    // Compute overall ranking for collaborative lists using average position (Borda-like)
    func aggregateRanking(for list: RankleList) -> [RankleItem] {
        guard list.isCollaborative, !list.collaborators.isEmpty else { return list.items }
        let itemIdToItem = Dictionary(uniqueKeysWithValues: list.items.map { ($0.id, $0) })
        let itemIds = list.items.map { $0.id }
        let n = itemIds.count

        var scores: [UUID: Double] = [:]
        for id in itemIds { scores[id] = 0 }
        for collab in list.collaborators {
            // Map positions; unseen items get bottom position
            var pos: [UUID: Int] = [:]
            for (idx, id) in collab.ranking.enumerated() { pos[id] = idx }
            for id in itemIds {
                let p = pos[id] ?? (n - 1)
                scores[id, default: 0] += Double(n - p)
            }
        }
        let sortedIds = itemIds.sorted { (a, b) -> Bool in
            (scores[a] ?? 0) > (scores[b] ?? 0)
        }
        return sortedIds.compactMap { itemIdToItem[$0] }
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
