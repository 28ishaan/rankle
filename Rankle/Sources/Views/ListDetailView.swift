import SwiftUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void
    @ObservedObject var listsViewModel: ListsViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var newItemTitle: String = ""
    @State private var isPresentingRanker = false
    @State private var isPresentingAddRanker = false
    @State private var isPresentingShareSheet = false
    @State private var isRefreshing = false
    
    // Computed property to get fresh list data from view model
    private var currentList: RankleList {
        listsViewModel.getList(id: list.id) ?? list
    }

    var body: some View {
        let freshList = currentList
        
        List {
            Section("Appearance") {
                HStack(spacing: 12) {
                    Circle()
                        .fill(freshList.color)
                        .frame(width: 24, height: 24)
                    ColorPicker("Icon Color", selection: Binding(get: { freshList.color }, set: { newColor in
                        var updated = freshList
                        updated.color = newColor
                        onUpdate(updated)
                    }), supportsOpacity: false)
                }
            }
            .listRowBackground(Color.themeRowBackground(colorScheme))
            Section("Collaboration") {
                let isOwner = freshList.ownerId == UserService.shared.currentUserId
                Toggle("Collaborative list", isOn: Binding(get: { freshList.isCollaborative }, set: { value in
                    // Only allow changes if user is owner
                    guard isOwner else { return }
                    
                    var updated = freshList
                    if value {
                        // Turning ON: set owner to current user if not already
                        if !updated.isCollaborative {
                            updated.ownerId = UserService.shared.currentUserId
                        }
                        updated.isCollaborative = true
                        onUpdate(updated)
                    } else {
                        // Turning OFF: only owner can do this
                        updated.isCollaborative = false
                        updated.collaborators.removeAll()
                        onUpdate(updated)
                    }
                }))
                .disabled(!isOwner)
                if !isOwner {
                    Text(freshList.isCollaborative 
                         ? "Only the owner can change collaboration settings."
                         : "Only the owner can enable collaboration.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.themeRowBackground(colorScheme))
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
            .listRowBackground(Color.themeRowBackground(colorScheme))
            if freshList.isCollaborative {
                Section("Overall Collaboration Ranking") {
                    let aggregated = listsViewModel.getAggregateRanking(for: freshList)
                    ForEach(Array(aggregated.enumerated()), id: \.element.id) { index, item in
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                            Text(item.title)
                        }
                    }
                }
            }
            Section("Ranked Items") {
                if freshList.items.isEmpty {
                    Text("No items yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(freshList.items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(destination: ItemDetailView(listId: freshList.id, item: item, onUpdate: { updatedItem in
                            var updated = freshList
                            if let idx = updated.items.firstIndex(where: { $0.id == updatedItem.id }) {
                                updated.items[idx] = updatedItem
                                onUpdate(updated)
                            }
                        }, isCollaborative: freshList.isCollaborative)) {
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                Text(item.title)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var updated = freshList
                        updated.items.remove(atOffsets: offsets)
                        onUpdate(updated)
                    }
                }
            }
            .listRowBackground(Color.themeRowBackground(colorScheme))
        }
        .refreshable {
            await refreshList()
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: Color.themeDetailBackground(colorScheme),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(freshList.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if freshList.isCollaborative {
                        Button {
                            Task {
                                await refreshList()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.primary)
                        }
                    }
                    Button {
                        isPresentingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }
                    EditButton()
                        .foregroundColor(.primary)
                    Button("Rank Items") { isPresentingRanker = true }
                        .foregroundColor(.primary)
                }
            }
        }
        .onReceive(listsViewModel.$lists) { lists in
            if let updated = lists.first(where: { $0.id == list.id }) {
                self.list = updated
            }
        }
        .onAppear {
            // Refresh collaborative lists when view appears
            if list.isCollaborative {
                listsViewModel.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh collaborative lists when app comes to foreground
            if list.isCollaborative {
                listsViewModel.refresh()
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
            RankingView(list: freshList) { updated in
                self.list = updated
                // If this is a collaborative list, save as collaborator contribution
                if updated.isCollaborative {
                    let ranking = CollaboratorRanking(
                        userId: UserService.shared.currentUserId,
                        displayName: nil,
                        ranking: updated.items.map { $0.id },
                        updatedAt: Date()
                    )
                    listsViewModel.upsertContribution(listId: updated.id, ranking: ranking)
                } else {
                    onUpdate(updated)
                }
            }
        }
        .sheet(isPresented: $isPresentingAddRanker) {
            let titles = newItemTitle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let newItems = titles.map { RankleItem(title: $0) }
            AddItemRankingView(existingItems: freshList.items, newItems: newItems, listId: freshList.id, isCollaborative: freshList.isCollaborative) { updatedItems in
                var updated = freshList
                updated.items = updatedItems
                newItemTitle = ""
                // If this is a collaborative list, save as collaborator contribution
                if updated.isCollaborative {
                    let ranking = CollaboratorRanking(
                        userId: UserService.shared.currentUserId,
                        displayName: nil,
                        ranking: updatedItems.map { $0.id },
                        updatedAt: Date()
                    )
                    listsViewModel.upsertContribution(listId: updated.id, ranking: ranking)
                } else {
                    onUpdate(updated)
                }
            }
        }
    }
    
    private func refreshList() async {
        isRefreshing = true
        listsViewModel.refresh()
        // Small delay to show refresh animation
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        if let updated = listsViewModel.getList(id: list.id) {
            self.list = updated
        }
        isRefreshing = false
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
    ListDetailView(
        list: RankleList(name: "Sample", items: ["A","B","C"].map { RankleItem(title: $0) }),
        onUpdate: { _ in },
        listsViewModel: ListsViewModel()
    )
}
