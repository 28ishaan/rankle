import SwiftUI
import PhotosUI

// MARK: - Transferable Item ID

struct DraggableItemID: Transferable, Codable {
    let id: UUID
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

struct TierListView: View {
    @State var list: RankleList
    var onUpdate: (RankleList) -> Void
    @ObservedObject var listsViewModel: ListsViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var newItemTitle: String = ""
    @State private var newImageItems: [RankleItem] = []
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var isPresentingShareSheet = false
    @State private var isRefreshing = false
    @State private var selectedItem: RankleItem?
    private let storage = StorageService()
    
    // Computed property to get fresh list data from view model
    private var currentList: RankleList {
        listsViewModel.getList(id: list.id) ?? list
    }
    
    var body: some View {
        let freshList = currentList
        
        ScrollView {
            VStack(spacing: 16) {
                // Tiers section
                ForEach(Tier.allCases) { tier in
                    tierSection(tier: tier, list: freshList)
                }
                
                // Unassigned items section
                if !freshList.unassignedItems.isEmpty {
                    unassignedSection(list: freshList)
                }
                
                // Add items section
                addItemsSection(list: freshList)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: Color.themeBackground(colorScheme),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(freshList.name)
        .toolbar {
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
                }
            }
        }
        .onReceive(listsViewModel.$lists) { lists in
            if let updated = lists.first(where: { $0.id == list.id }) {
                self.list = updated
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(listId: list.id, item: item, onUpdate: { updatedItem in
                    var updated = currentList
                    if let idx = updated.items.firstIndex(where: { $0.id == updatedItem.id }) {
                        updated.items[idx] = updatedItem
                        onUpdate(updated)
                    }
                    selectedItem = nil
                }, isCollaborative: list.isCollaborative)
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
    }
    
    // MARK: - Tier Section
    
    private func tierSection(tier: Tier, list: RankleList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tier header
            HStack {
                Text(tier.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(tier.color)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text("\(list.itemsInTier(tier).count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.themeRowBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Items in tier - wrap in a drop zone container
            ZStack {
                // Invisible background for drop zone
                Rectangle()
                    .fill(Color.clear)
                    .frame(minHeight: 100)
                    .contentShape(Rectangle())
                    .dropDestination(for: DraggableItemID.self) { droppedItems, _ in
                        handleDrop(itemIds: droppedItems.map { $0.id }, to: tier, list: list)
                    }
                
                // Items grid
                VStack(spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(list.itemsInTier(tier)) { item in
                            tierItemCard(item: item, tier: tier, list: list)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func tierItemCard(item: RankleItem, tier: Tier, list: RankleList) -> some View {
        VStack(spacing: 4) {
            // Show image thumbnail if item has an image
            if let firstMedia = item.media.first,
               firstMedia.type == .image,
               let uiImage = UIImage(contentsOfFile: storage.urlForMedia(filename: firstMedia.filename).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.themeRowBackground(colorScheme))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            
            // Show title or "Image" for image-only items
            Text(item.title.isEmpty && !item.media.isEmpty ? "Image" : item.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(width: 100)
        .padding(8)
        .background(Color.themeRowBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .draggable(DraggableItemID(id: item.id))
        .onTapGesture {
            selectedItem = item
        }
    }
    
    // MARK: - Unassigned Section
    
    private func unassignedSection(list: RankleList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unassigned")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.themeRowBackground(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            ZStack {
                // Invisible background for drop zone
                Rectangle()
                    .fill(Color.clear)
                    .frame(minHeight: 100)
                    .contentShape(Rectangle())
                    .dropDestination(for: DraggableItemID.self) { droppedItems, _ in
                        handleDrop(itemIds: droppedItems.map { $0.id }, to: nil, list: list) // nil means unassigned
                    }
                
                // Items grid
                VStack(spacing: 8) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(list.unassignedItems) { item in
                            tierItemCard(item: item, tier: .f, list: list) // Use .f as placeholder, won't be used
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Add Items Section
    
    private func addItemsSection(list: RankleList) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Items")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("Item name", text: $newItemTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    var updated = list
                    updated.items.append(RankleItem(title: trimmed))
                    newItemTitle = ""
                    onUpdate(updated)
                }
                .buttonStyle(ThemeButtonStyle())
                .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            if !list.isCollaborative {
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
                                    var updated = list
                                    updated.items.append(rankleItem)
                                    onUpdate(updated)
                                }
                            }
                        }
                        selectedImages.removeAll()
                    }
                }
            }
        }
        .padding()
        .background(Color.themeRowBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    
    // MARK: - Drag and Drop
    
    private func handleDrop(itemIds: [UUID], to tier: Tier?, list: RankleList) -> Bool {
        var updated = list
        var hasChanges = false
        
        for itemId in itemIds {
            // Remove from current tier assignment
            updated.tierAssignments.removeValue(forKey: itemId)
            
            // Assign to new tier if provided
            if let tier = tier {
                updated.tierAssignments[itemId] = tier.rawValue
            }
            // If tier is nil, item becomes unassigned (already removed above)
            
            hasChanges = true
        }
        
        if hasChanges {
            onUpdate(updated)
        }
        
        return hasChanges
    }
    
    // MARK: - Helper Methods
    
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
    NavigationStack {
        TierListView(
            list: RankleList(name: "Sample Tier List", items: [
                RankleItem(title: "Item 1"),
                RankleItem(title: "Item 2"),
                RankleItem(title: "Item 3")
            ], listType: .tier),
            onUpdate: { _ in },
            listsViewModel: ListsViewModel()
        )
    }
}

