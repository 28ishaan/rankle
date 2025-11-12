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
        
        // Save to CloudKit if collaborative
        if isCollaborative {
            Task {
                do {
                    try await cloudKit.saveList(newList)
                    // Subscribe to changes
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
        // Remove media from items if creating a collaborative list (CloudKit doesn't support media)
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
        
        // Save to CloudKit if collaborative
        if isCollaborative {
            Task {
                do {
                    try await cloudKit.saveList(newList)
                    // Subscribe to changes
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

    func deleteList(at offsets: IndexSet) {
        // Only allow deleting collaborative lists if current user is owner
        var allowed = IndexSet()
        var skippedCount = 0
        for idx in offsets {
            // Bounds check to prevent crashes
            guard idx < lists.count else { continue }
            
            let list = lists[idx]
            if list.isCollaborative {
                if list.ownerId == UserService.shared.currentUserId {
                    allowed.insert(idx)
                } else {
                    // skip non-owner deletes - collaborative lists can only be deleted by owner
                    skippedCount += 1
                }
            } else {
                allowed.insert(idx)
            }
        }
        if !allowed.isEmpty {
            lists.remove(atOffsets: allowed)
            persist()
        }
        // Note: skippedCount could be used to show an alert, but SwiftUI .onDelete doesn't easily support this
    }
    
    // Check if a list can be deleted by current user
    func canDeleteList(_ list: RankleList) -> Bool {
        if list.isCollaborative {
            return list.ownerId == UserService.shared.currentUserId
        }
        return true
    }

    func renameList(_ listId: UUID, newName: String) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[index].name = newName
        persist()
    }

    func updateColor(_ color: Color, for listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[index].color = color
        persist()
    }

    func addItem(_ title: String, to listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        lists[index].items.append(RankleItem(title: title))
        persist()
    }

    func replaceList(_ updated: RankleList) {
        guard let index = lists.firstIndex(where: { $0.id == updated.id }) else { return }
        lists[index] = updated
        persist()
    }
    
    func importList(_ list: RankleList) {
        // Generate new ID to avoid conflicts
        var imported = RankleList(name: list.name, items: list.items, color: list.color, isCollaborative: list.isCollaborative)
        // Imported lists are owned by the importer
        imported.ownerId = UserService.shared.currentUserId
        lists.append(imported)
        persist()
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
        
        // Save to CloudKit
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
        
        // Update CloudKit
        if enabled {
            Task {
                do {
                    try await cloudKit.saveList(list)
                    _ = try await cloudKit.subscribeToListChanges(listId: list.id)
                    _ = try await cloudKit.subscribeToContributionChanges(listId: list.id)
                } catch {
                    #if DEBUG
                    print("CloudKit save error: \(error)")
                    #endif
                }
            }
        }
    }

    // Refresh lists from storage (useful for syncing collaborative lists)
    func refresh() {
        lists = storage.loadLists()
        // Also sync with CloudKit
        Task {
            await syncWithCloudKit()
        }
    }
    
    // Sync with CloudKit
    @MainActor
    func syncWithCloudKit() async {
        // Check account status
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
        
        // Fetch all collaborative lists from CloudKit
        do {
            let cloudLists = try await cloudKit.fetchAllLists()
            
            // Merge with local lists
            var mergedLists = lists
            for cloudList in cloudLists {
                if let index = mergedLists.firstIndex(where: { $0.id == cloudList.id }) {
                    // Update existing list if CloudKit version is newer or if it's collaborative
                    if cloudList.isCollaborative {
                        mergedLists[index] = cloudList
                    }
                } else {
                    // Add new list from CloudKit
                    if cloudList.isCollaborative {
                        mergedLists.append(cloudList)
                    }
                }
            }
            
            // Save merged lists locally
            storage.saveLists(mergedLists)
            lists = mergedLists
            
            // Fetch and update contributions for all collaborative lists
            for list in mergedLists where list.isCollaborative {
                do {
                    let contributions = try await cloudKit.fetchContributions(for: list.id)
                    var updatedList = list
                    updatedList.collaborators = contributions
                    let aggregated = storage.aggregateRanking(for: updatedList)
                    updatedList.items = aggregated
                    
                    if let index = lists.firstIndex(where: { $0.id == updatedList.id }) {
                        lists[index] = updatedList
                    }
                } catch {
                    #if DEBUG
                    print("Error fetching contributions for list \(list.id): \(error)")
                    #endif
                }
            }
            
            storage.saveLists(lists)
        } catch {
            #if DEBUG
            print("CloudKit sync error: \(error)")
            #endif
            // Fall back to local storage
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

    private func persist() {
        storage.saveLists(lists)
    }
}
