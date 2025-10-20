import SwiftUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void

    @State private var newItemTitle: String = ""
    @State private var isPresentingRanker = false
    @State private var isPresentingAddRanker = false

    var body: some View {
        List {
            Section("Appearance") {
                HStack(spacing: 12) {
                    Circle()
                        .fill(list.color)
                        .frame(width: 24, height: 24)
                    ColorPicker("Icon Color", selection: Binding(get: { list.color }, set: { newColor in
                        list.color = newColor
                        onUpdate(list)
                    }), supportsOpacity: false)
                }
            }
            Section("Add Items (comma-separated)") {
                HStack {
                    TextField("e.g., Item A, Item B, Item C", text: $newItemTitle)
                    Button("Add & Rank") {
                        let titles = newItemTitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        guard !titles.isEmpty else { return }
                        isPresentingAddRanker = true
                    }
                    .buttonStyle(ThemeButtonStyle())
                    .disabled(newItemTitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty)
                }
            }
            Section("Ranked Items") {
                if list.items.isEmpty {
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(destination: ItemDetailView(listId: list.id, item: item, onUpdate: { updatedItem in
                            if let idx = list.items.firstIndex(where: { $0.id == updatedItem.id }) {
                                list.items[idx] = updatedItem
                                onUpdate(list)
                            }
                        })) {
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                            }
                        }
                    }
                    .onDelete { offsets in
                        list.items.remove(atOffsets: offsets)
                        onUpdate(list)
                    }
                }
            }
        }
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Rank Items") { isPresentingRanker = true }
            }
        }
        .sheet(isPresented: $isPresentingRanker) {
            RankingView(list: list) { updated in
                self.list = updated
                onUpdate(updated)
            }
        }
        .sheet(isPresented: $isPresentingAddRanker) {
            let titles = newItemTitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let newItems = titles.map { RankleItem(title: $0) }
            AddItemRankingView(existingItems: list.items, newItems: newItems) { updatedItems in
                list.items = updatedItems
                newItemTitle = ""
                onUpdate(list)
            }
        }
    }
}

#Preview {
    ListDetailView(list: RankleList(name: "Sample", items: ["A","B","C"].map { RankleItem(title: $0) })) { _ in }
}
