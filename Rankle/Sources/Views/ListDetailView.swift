import SwiftUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void

    @State private var newItemTitle: String = ""
    @State private var isPresentingRanker = false

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
            Section {
                HStack {
                    TextField("Add new item", text: $newItemTitle)
                    Button("Add") {
                        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        list.items.append(RankleItem(title: title))
                        newItemTitle = ""
                        onUpdate(list)
                    }
                    .buttonStyle(ThemeButtonStyle())
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
    }
}

#Preview {
    ListDetailView(list: RankleList(name: "Sample", items: ["A","B","C"].map { RankleItem(title: $0) })) { _ in }
}
