import SwiftUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void

    @State private var newItemTitle: String = ""
    @State private var isPresentingRanker = false

    var body: some View {
        List {
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
                    .buttonStyle(.borderedProminent)
                }
            }
            Section("Ranked Items") {
                if list.items.isEmpty {
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundStyle(.secondary)
                            Text(item.title)
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
