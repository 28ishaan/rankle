import SwiftUI
import PhotosUI

struct ListDetailView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void
    @ObservedObject var listsViewModel: ListsViewModel
    @Environment(\.colorScheme) var colorScheme

    @State private var newItemTitle: String = ""
    @State private var newImageItems: [RankleItem] = []
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var isPresentingRanker = false
    @State private var isPresentingAddRanker = false
    @State private var isPresentingShareSheet = false
    @State private var isRefreshing = false
    private let storage = StorageService()
    
    // Computed property to get fresh list data from view model
    private var currentList: RankleList {
        listsViewModel.getList(id: list.id) ?? list
    }

    var body: some View {
        let freshList = currentList
        
        List {
            appearanceSection(freshList: freshList)
            collaborationSection(freshList: freshList)
            addItemsSection(freshList: freshList)
            if freshList.isCollaborative {
                collaborationRankingSection(freshList: freshList)
            }
            rankedItemsSection(freshList: freshList)
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
            if currentList.isCollaborative {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await refreshList()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
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
            let textItems = titles.map { RankleItem(title: $0) }
            let combinedItems = textItems + newImageItems
            AddItemRankingView(existingItems: freshList.items, newItems: combinedItems, listId: freshList.id, isCollaborative: freshList.isCollaborative) { updatedItems in
                var updated = freshList
                updated.items = updatedItems
                newItemTitle = ""
                newImageItems.removeAll()
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
    
    // MARK: - View Sections
    
    private func appearanceSection(freshList: RankleList) -> some View {
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
    }
    
    private func collaborationSection(freshList: RankleList) -> some View {
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
    }
    
    private func addItemsSection(freshList: RankleList) -> some View {
        let hasTextItems = !newItemTitle.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .isEmpty
        
        return Section("Add Items") {
            HStack {
                TextField("e.g., Item A, Item B, Item C", text: $newItemTitle)
                Button("Add & Rank") {
                    let titles = newItemTitle.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    guard !titles.isEmpty || !newImageItems.isEmpty else { return }
                    isPresentingAddRanker = true
                }
                .buttonStyle(ThemeButtonStyle())
                .disabled(!hasTextItems && newImageItems.isEmpty)
            }
            
            if !freshList.isCollaborative {
                imagePickerSection
            }
            
            if !newImageItems.isEmpty {
                imagePreviewSection
            }
        }
        .listRowBackground(Color.themeRowBackground(colorScheme))
    }
    
    private var imagePickerSection: some View {
        PhotosPicker(selection: $selectedImages, maxSelectionCount: 1, matching: .images) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                Text("Add Image as Item")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .onChange(of: selectedImages) { newItems in
            Task {
                if let itemProvider = newItems.first {
                    if let data = try? await itemProvider.loadTransferable(type: Data.self),
                       let utType = itemProvider.supportedContentTypes.first {
                        let ext = utType.preferredFilenameExtension ?? "jpg"
                        if let filename = try? storage.saveMedia(data: data, fileExtension: ext) {
                            let mediaItem = MediaItem(type: .image, filename: filename)
                            let rankleItem = RankleItem(title: "", media: [mediaItem])
                            newImageItems.append(rankleItem)
                        }
                    }
                }
                selectedImages.removeAll()
            }
        }
    }
    
    private var imagePreviewSection: some View {
        ForEach(newImageItems) { item in
            HStack {
                if let firstMedia = item.media.first,
                   let uiImage = UIImage(contentsOfFile: storage.urlForMedia(filename: firstMedia.filename).path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Image")
                    .foregroundColor(.secondary)
            }
        }
        .onDelete { offsets in
            newImageItems.remove(atOffsets: offsets)
        }
    }
    
    private func collaborationRankingSection(freshList: RankleList) -> some View {
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
    
    private func rankedItemsSection(freshList: RankleList) -> some View {
        Section("Ranked Items") {
            if freshList.items.isEmpty {
                Text("No items yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(freshList.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: itemDetailDestination(freshList: freshList, item: item)) {
                        itemRowView(index: index, item: item)
                    }
                }
                .onDelete { offsets in
                    handleDelete(offsets: offsets, freshList: freshList)
                }
                .onMove { source, destination in
                    handleMove(from: source, to: destination, freshList: freshList)
                }
            }
        }
        .listRowBackground(Color.themeRowBackground(colorScheme))
    }
    
    private func itemDetailDestination(freshList: RankleList, item: RankleItem) -> some View {
        ItemDetailView(listId: freshList.id, item: item, onUpdate: { updatedItem in
            var updated = freshList
            if let idx = updated.items.firstIndex(where: { $0.id == updatedItem.id }) {
                updated.items[idx] = updatedItem
                onUpdate(updated)
            }
        }, isCollaborative: freshList.isCollaborative)
    }
    
    private func itemRowView(index: Int, item: RankleItem) -> some View {
        HStack {
            Text("\(index + 1).")
                .foregroundColor(.secondary)
            
            // Show image thumbnail if item has an image
            if let firstMedia = item.media.first,
               firstMedia.type == .image,
               let uiImage = UIImage(contentsOfFile: StorageService().urlForMedia(filename: firstMedia.filename).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Show title or "Image" for image-only items
            Text(item.title.isEmpty && !item.media.isEmpty ? "Image" : item.title)
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func handleDelete(offsets: IndexSet, freshList: RankleList) {
        var updated = freshList
        updated.items.remove(atOffsets: offsets)
        
        // Update local state immediately
        self.list = updated
        
        if updated.isCollaborative {
            // For collaborative lists, save as contribution
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
    
    private func handleMove(from source: IndexSet, to destination: Int, freshList: RankleList) {
        var updated = freshList
        updated.items.move(fromOffsets: source, toOffset: destination)
        
        // Update local state immediately
        self.list = updated
        
        if updated.isCollaborative {
            // For collaborative lists, save as contribution
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
