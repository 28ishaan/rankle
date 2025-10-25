import SwiftUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void

    @State private var newItemTitle: String = ""
    @State private var isPresentingRanker = false
    @State private var isPresentingAddRanker = false
    @State private var isPresentingShareSheet = false

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
                        .foregroundColor(.secondary)
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
                                    .foregroundColor(.secondary)
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
                HStack(spacing: 12) {
                    Button {
                        isPresentingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    EditButton()
                    Button("Rank Items") { isPresentingRanker = true }
                }
            }
        }
        .confirmationDialog("Share List", isPresented: $isPresentingShareSheet) {
            Button("Share to Rankle Users") {
                shareToRankleUsers()
            }
            Button("Copy to Clipboard") {
                copyToClipboard()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how to share this list")
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
    
    private func shareToRankleUsers() {
        guard let url = SharingService.shared.generateDeepLink(for: list) else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = window
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func copyToClipboard() {
        let text = SharingService.shared.generateClipboardText(for: list)
        SharingService.shared.copyToClipboard(text)
    }
}

#Preview {
    ListDetailView(list: RankleList(name: "Sample", items: ["A","B","C"].map { RankleItem(title: $0) })) { _ in }
}
