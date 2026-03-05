import Foundation
import Combine
import SwiftUI
import CloudKit

final class ListsViewModel: ObservableObject {
    @Published private(set) var lists: [RankleList] = []

    private let storage: StorageService
    private let cloudKit: CloudKitService
    
    private var subscriptions: Set<CKSubscription> = []

    init(storage: StorageService = StorageService(), cloudKit: CloudKitService = .shared) {
        self.storage = storage
        self.cloudKit = cloudKit
        self.lists = storage.loadLists()
        
        // Sync with CloudKit on init (async)
        Task {
            await syncWithCloudKit()
        }

        // Re-subscribe to CloudKit changes for all known collaborative lists.
        // Subscriptions can be lost after a reinstall or expire; re-registering is idempotent
        // (CloudKit silently ignores duplicate subscription IDs).
        Task {
            await resubscribeToCollaborativeLists()
        }
        
        // Set up notification observers
        NotificationCenter.default.addObserver(
            forName: .cloudKitPushNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.syncWithCloudKit()
            }
        }
    }

    func createList(name: String, items: [String], color: Color = .cyan, isCollaborative: Bool = false) {
        let rankleItems = items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RankleItem(title: $0) }
        var newList = RankleList(name: name, items: rankleItems, isCollaborative: isCollaborative)
        newList.color = color
        newList.ownerId = UserService.shared.currentUserId
        lists.append(newList)
        persist()
        
        if isCollaborative {
            Task {
                do {
                    try await cloudKit.saveList(newList)
                    _ = try await cloudKit.subscribeToListChanges(listId: newList.id)
                    _ = try await cloudKit.subscribeToContributionChanges(listId: newList.id)
                } catch {
                    #if DEBUG
                    print("CloudKit save error: \(error)")
                    #endif
                }
            }
        }
    }
    
    func createListWithItems(name: String, items: [RankleItem], color: Color = .cyan, isCollaborative: Bool = false) {
        let processedItems = isCollaborative ? items.map { item in
            var updatedItem = item
            updatedItem.media.removeAll()
            return updatedItem
        } : items
        
        var newList = RankleList(name: name, items: processedItems, isCollaborative: isCollaborative)
        newList.color = color
        newList.ownerId = UserService.shared.currentUserId
        lists.append(newList)
        persist()
        
        if isCollaborative {
            Task {
                do {
                    try await cloudKit.saveList(newList)
                    _ = try await cloudKit.subscribeToListChanges(listId: newList.id)
                    _ = try await cloudKit.subscribeToContributionChanges(listId: newList.id)
                } catch {
                    #if DEBUG
                    print("CloudKit save error: \(error)")
                    #endif
                }
            }
        }
    }
    
    func createTierList(name: String, items: [String], color: Color = .cyan, isCollaborative: Bool = false) {
        let rankleItems = items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RankleItem(title: $0) }
        var newList = RankleList(name: name, items: rankleItems, isCollaborative: false, listType: .tier)
        newList.color = color
        newList.ownerId = UserService.shared.currentUserId
        // Tier lists cannot be collaborative
        newList.isCollaborative = false
        lists.append(newList)
        persist()
    }
    
    func createTierListWithItems(name: String, items: [RankleItem], color: Color = .cyan, isCollaborative: Bool = false) {
        var newList = RankleList(name: name, items: items, isCollaborative: false, listType: .tier)
        newList.color = color
        newList.ownerId = UserService.shared.currentUserId
        // Tier lists cannot be collaborative
        newList.isCollaborative = false
        lists.append(newList)
        persist()
    }

    func deleteList(at offsets: IndexSet) {
        var allowed = IndexSet()
        for idx in offsets {
            guard idx < lists.count else { continue }
            let list = lists[idx]
            if canDeleteList(list) {
                allowed.insert(idx)
            }
        }
        if !allowed.isEmpty {
            // Delete from CloudKit for owned collaborative lists
            let toDelete = allowed.map { lists[$0] }.filter { $0.isCollaborative }
            lists.remove(atOffsets: allowed)
            persist()
            
            for list in toDelete {
                Task {
                    try? await cloudKit.deleteList(id: list.id)
                }
            }
        }
    }
    
    // Check if a list can be deleted by current user
    func canDeleteList(_ list: RankleList) -> Bool {
        if list.isCollaborative {
            return list.ownerId == UserService.shared.currentUserId
        }
        return true
    }
    
    /// Remove a shared collaborative list from local storage without deleting
    /// the CloudKit record — used by collaborators who want to stop following a list.
    func leaveList(id: UUID) {
        lists.removeAll { $0.id == id }
        persist()
    }
    
    // Check if the current user can edit the structure of a list
    // (add/remove items, rename, change color, reorder)
    func canEditList(_ list: RankleList) -> Bool {
        if list.isCollaborative {
            return list.ownerId == UserService.shared.currentUserId
        }
        return true
    }

    func renameList(_ listId: UUID, newName: String) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        guard canEditList(lists[index]) else { return }
        lists[index].name = newName
        persist()
        syncListToCloudKitIfCollaborative(lists[index])
    }

    func updateColor(_ color: Color, for listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        guard canEditList(lists[index]) else { return }
        lists[index].color = color
        persist()
        syncListToCloudKitIfCollaborative(lists[index])
    }

    func addItem(_ title: String, to listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        guard canEditList(lists[index]) else { return }
        lists[index].items.append(RankleItem(title: title))
        persist()
        syncListToCloudKitIfCollaborative(lists[index])
    }

    func replaceList(_ updated: RankleList) {
        guard let index = lists.firstIndex(where: { $0.id == updated.id }) else { return }
        lists[index] = updated
        persist()
        syncListToCloudKitIfCollaborative(updated)
    }
    
    /// Import a list received via a share link.
    /// For collaborative lists: preserves the original ID and owner so contributions
    /// route correctly back to the owner's list. The importer becomes a collaborator.
    /// For non-collaborative lists: creates a local copy with a new ID (importer owns it).
    func importList(_ list: RankleList) {
        if list.isCollaborative {
            // Avoid importing a duplicate
            if lists.contains(where: { $0.id == list.id }) { return }
            
            // Preserve original ID and ownerId — the current user is a collaborator, not the owner
            lists.append(list)
            persist()
            
            // Subscribe to changes so we receive push notifications when the list or
            // its contributions are updated
            Task {
                do {
                    _ = try await cloudKit.subscribeToListChanges(listId: list.id)
                    _ = try await cloudKit.subscribeToContributionChanges(listId: list.id)
                } catch {
                    #if DEBUG
                    print("CloudKit subscription error on import: \(error)")
                    #endif
                }
            }
        } else {
            // Non-collaborative: give a fresh ID so there are no conflicts and the
            // importer owns their local copy
            var imported = RankleList(name: list.name, items: list.items, color: list.color, isCollaborative: false)
            imported.ownerId = UserService.shared.currentUserId
            lists.append(imported)
            persist()
        }
    }

    // Apply collaborator contribution (or replace existing if same user)
    func upsertContribution(listId: UUID, ranking: CollaboratorRanking) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        var list = lists[index]
        
        // Only save contributions for collaborative lists
        guard list.isCollaborative else { return }
        
        if let cidx = list.collaborators.firstIndex(where: { $0.userId == ranking.userId }) {
            list.collaborators[cidx] = ranking
        } else {
            list.collaborators.append(ranking)
        }
        // Update overall ordering snapshot
        let aggregated = storage.aggregateRanking(for: list)
        list.items = aggregated
        lists[index] = list
        persist()
        
        // Save to CloudKit public database so all collaborators can read it
        Task {
            do {
                try await cloudKit.saveContribution(ranking, for: listId)
            } catch {
                #if DEBUG
                print("CloudKit contribution save error: \(error)")
                #endif
            }
        }
    }

    // Toggle collaborative state; only owner can enable or disable.
    func setCollaborative(_ enabled: Bool, for listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        var list = lists[index]
        
        // Only owner can change collaboration status
        guard list.ownerId == UserService.shared.currentUserId else { return }
        
        if enabled {
            list.isCollaborative = true
            // Remove media from all items when enabling collaboration
            list.items = list.items.map { item in
                RankleItem(id: item.id, title: item.title, media: [])
            }
        } else {
            list.isCollaborative = false
            list.collaborators.removeAll()
        }
        // If enabled, recalc overall (initially just owner ordering)
        if list.isCollaborative {
            list.items = storage.aggregateRanking(for: list)
        }
        lists[index] = list
        persist()

        Task {
            do {
                if enabled {
                    // Save new collaborative record and register for real-time updates.
                    try await cloudKit.saveList(list)
                    _ = try await cloudKit.subscribeToListChanges(listId: list.id)
                    _ = try await cloudKit.subscribeToContributionChanges(listId: list.id)
                } else {
                    // Push the non-collaborative version so remote devices stop treating
                    // this list as collaborative (they see isCollaborative = false on next sync).
                    try await cloudKit.saveList(list)
                }
            } catch {
                #if DEBUG
                print("CloudKit save error: \(error)")
                #endif
            }
        }
    }

    // Refresh lists from storage (useful for syncing collaborative lists)
    func refresh() {
        lists = storage.loadLists()
        Task {
            await syncWithCloudKit()
        }
    }
    
    // Sync with CloudKit public database
    @MainActor
    func syncWithCloudKit() async {
        do {
            let status = try await cloudKit.checkAccountStatus()
            guard status == .available else {
                #if DEBUG
                print("iCloud account not available")
                #endif
                return
            }
        } catch {
            #if DEBUG
            print("CloudKit account check error: \(error)")
            #endif
            return
        }
        
        let currentUserId = UserService.shared.currentUserId
        
        do {
            // 1. Fetch lists this user owns from the public database
            let ownedCloudLists = try await cloudKit.fetchOwnedLists(ownerId: currentUserId)
            
            // 2. For locally-stored collaborative lists the current user does NOT own
            //    (i.e., lists shared with them), fetch the latest version by ID so they
            //    see structural updates the owner may have made.
            let sharedLocalLists = lists.filter {
                $0.isCollaborative && $0.ownerId != currentUserId
            }
            var sharedCloudLists: [RankleList] = []
            for localList in sharedLocalLists {
                if let cloudList = try? await cloudKit.fetchListById(id: localList.id) {
                    sharedCloudLists.append(cloudList)
                }
            }
            
            let allCloudLists = ownedCloudLists + sharedCloudLists
            
            // 3. Merge cloud versions into local list array
            var mergedLists = lists
            for cloudList in allCloudLists {
                if let idx = mergedLists.firstIndex(where: { $0.id == cloudList.id }) {
                    mergedLists[idx] = cloudList
                } else {
                    mergedLists.append(cloudList)
                }
            }
            
            // 4. Fetch and apply contributions for every collaborative list
            for list in mergedLists where list.isCollaborative {
                do {
                    let contributions = try await cloudKit.fetchContributions(for: list.id)
                    var updatedList = list
                    updatedList.collaborators = contributions
                    updatedList.items = storage.aggregateRanking(for: updatedList)
                    
                    if let idx = mergedLists.firstIndex(where: { $0.id == updatedList.id }) {
                        mergedLists[idx] = updatedList
                    }
                } catch {
                    #if DEBUG
                    print("Error fetching contributions for list \(list.id): \(error)")
                    #endif
                }
            }
            
            storage.saveLists(mergedLists)
            lists = mergedLists
            
        } catch {
            #if DEBUG
            print("CloudKit sync error: \(error)")
            #endif
            lists = storage.loadLists()
        }
    }
    
    // Get a fresh copy of a list from storage
    func getList(id: UUID) -> RankleList? {
        return lists.first(where: { $0.id == id })
    }
    
    // Get aggregate ranking for a collaborative list
    func getAggregateRanking(for list: RankleList) -> [RankleItem] {
        return storage.aggregateRanking(for: list)
    }

    // Re-register CloudKit subscriptions for all collaborative lists the app already knows about.
    // Called on launch so subscriptions survive reinstalls or other loss events.
    // CloudKit silently ignores duplicate subscription IDs so this is safe to call repeatedly.
    @MainActor
    private func resubscribeToCollaborativeLists() async {
        for list in lists where list.isCollaborative {
            do {
                _ = try await cloudKit.subscribeToListChanges(listId: list.id)
                _ = try await cloudKit.subscribeToContributionChanges(listId: list.id)
            } catch {
                #if DEBUG
                print("Re-subscription error for list \(list.id): \(error)")
                #endif
            }
        }
    }

    private func persist() {
        storage.saveLists(lists)
    }

    // Push a collaborative list to CloudKit when the owner mutates it
    private func syncListToCloudKitIfCollaborative(_ list: RankleList) {
        guard list.isCollaborative,
              list.ownerId == UserService.shared.currentUserId else { return }
        Task {
            do {
                try await cloudKit.saveList(list)
            } catch {
                #if DEBUG
                print("CloudKit list sync error: \(error)")
                #endif
            }
        }
    }
}
