import Foundation
import Combine
import SwiftUI

final class ListsViewModel: ObservableObject {
    @Published private(set) var lists: [RankleList] = []

    private let storage: StorageService

    init(storage: StorageService = StorageService()) {
        self.storage = storage
        self.lists = storage.loadLists()
    }

    func createList(name: String, items: [String], color: Color = .cyan, isCollaborative: Bool = false) {
        let rankleItems = items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RankleItem(title: $0) }
        var newList = RankleList(name: name, items: rankleItems, isCollaborative: isCollaborative)
        newList.color = color
        newList.ownerId = UserService.shared.currentUserId
        lists.append(newList)
        persist()
    }

    func deleteList(at offsets: IndexSet) {
        // Only allow deleting collaborative lists if current user is owner
        var allowed = IndexSet()
        for idx in offsets {
            let list = lists[idx]
            if list.isCollaborative {
                if list.ownerId == UserService.shared.currentUserId {
                    allowed.insert(idx)
                } else {
                    // skip non-owner deletes
                }
            } else {
                allowed.insert(idx)
            }
        }
        if !allowed.isEmpty {
            lists.remove(atOffsets: allowed)
            persist()
        }
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
        if let cidx = list.collaborators.firstIndex(where: { $0.userId == ranking.userId }) {
            list.collaborators[cidx] = ranking
        } else {
            list.collaborators.append(ranking)
        }
        // Update overall ordering snapshot
        if list.isCollaborative {
            let aggregated = storage.aggregateRanking(for: list)
            list.items = aggregated
        }
        lists[index] = list
        persist()
    }

    // Toggle collaborative state; only owner can disable. Anyone can enable on their own lists they own.
    func setCollaborative(_ enabled: Bool, for listId: UUID) {
        guard let index = lists.firstIndex(where: { $0.id == listId }) else { return }
        var list = lists[index]
        if enabled {
            list.isCollaborative = true
        } else {
            // Only owner can disable collaboration
            guard list.ownerId == UserService.shared.currentUserId else { return }
            list.isCollaborative = false
            list.collaborators.removeAll()
        }
        // If enabled, recalc overall (initially just owner ordering)
        if list.isCollaborative {
            list.items = storage.aggregateRanking(for: list)
        }
        lists[index] = list
        persist()
    }

    private func persist() {
        storage.saveLists(lists)
    }
}
