import Foundation

final class StorageService {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let listsFileURL: URL
    private let backupFileURL: URL
    private let mediaDirectoryURL: URL

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        if let baseDirectoryURL {
            self.directoryURL = baseDirectoryURL
        } else {
            self.directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        self.listsFileURL = directoryURL.appendingPathComponent("rankle_lists.json")
        self.backupFileURL = directoryURL.appendingPathComponent("rankle_lists.backup.json")
        self.mediaDirectoryURL = directoryURL.appendingPathComponent("Media", isDirectory: true)
        try? fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)

        // Attempt one-time migration from potential legacy locations/filenames
        migrateLegacyListsIfNeeded()
    }

    func loadLists() -> [RankleList] {
        // Prefer primary file; if missing, try backup and legacy sources
        if fileManager.fileExists(atPath: listsFileURL.path) {
            if let lists: [RankleList] = decodeLists(at: listsFileURL) {
                return lists
            }
        }

        if fileManager.fileExists(atPath: backupFileURL.path) {
            if let lists: [RankleList] = decodeLists(at: backupFileURL) {
                // Restore from backup by promoting it to primary
                try? fileManager.removeItem(at: listsFileURL)
                try? fileManager.copyItem(at: backupFileURL, to: listsFileURL)
                return lists
            }
        }

        // As a last resort, try migrating legacy files now
        migrateLegacyListsIfNeeded()
        if let lists: [RankleList] = decodeLists(at: listsFileURL) {
            return lists
        }

        return []
    }

    func saveLists(_ lists: [RankleList]) {
        do {
            // Before writing new data, rotate a backup of the last good state
            if fileManager.fileExists(atPath: listsFileURL.path) {
                try? fileManager.removeItem(at: backupFileURL)
                try? fileManager.copyItem(at: listsFileURL, to: backupFileURL)
            }
            let data = try JSONEncoder().encode(lists)
            try data.write(to: listsFileURL, options: [.atomic])
            // After a successful write, ensure backup mirrors the latest good state too
            try? fileManager.removeItem(at: backupFileURL)
            try? fileManager.copyItem(at: listsFileURL, to: backupFileURL)
        } catch {
            // Ignore write errors, but keep backup if present
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

    // MARK: - Private helpers

    private func decodeLists(at url: URL) -> [RankleList]? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([RankleList].self, from: data)
        } catch {
            return nil
        }
    }

    private func migrateLegacyListsIfNeeded() {
        guard !fileManager.fileExists(atPath: listsFileURL.path) else { return }

        // Candidate legacy locations/filenames from earlier builds
        var candidates: [URL] = []

        // Same directory, different filenames that may have been used
        let possibleNames = [
            "lists.json",
            "rankle.json",
            "data.json",
            "rankle_lists_v1.json"
        ]
        for name in possibleNames {
            candidates.append(directoryURL.appendingPathComponent(name))
        }

        // Application Support directory variations
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in ["rankle_lists.json", "lists.json", "rankle.json"] {
                candidates.append(appSupport.appendingPathComponent(name))
            }
        }

        // Caches directory (unlikely, but cheap to check)
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            for name in ["rankle_lists.json", "lists.json"] {
                candidates.append(caches.appendingPathComponent(name))
            }
        }

        // First decodable candidate wins; copy into the new canonical location
        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            if let _: [RankleList] = decodeLists(at: candidate) {
                try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try? fileManager.copyItem(at: candidate, to: listsFileURL)
                // Also seed backup
                try? fileManager.removeItem(at: backupFileURL)
                try? fileManager.copyItem(at: listsFileURL, to: backupFileURL)
                break
            }
        }
    }
}
