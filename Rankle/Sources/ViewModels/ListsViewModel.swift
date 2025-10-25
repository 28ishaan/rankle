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

    func createList(name: String, items: [String], color: Color = .cyan) {
        let rankleItems = items.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { RankleItem(title: $0) }
        var newList = RankleList(name: name, items: rankleItems)
        newList.color = color
        lists.append(newList)
        persist()
    }

    func deleteList(at offsets: IndexSet) {
        lists.remove(atOffsets: offsets)
        persist()
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
        let imported = RankleList(name: list.name, items: list.items, color: list.color)
        lists.append(imported)
        persist()
    }

    private func persist() {
        storage.saveLists(lists)
    }
}
