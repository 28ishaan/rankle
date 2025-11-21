import SwiftUI
import PhotosUI

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var currentItem: String = ""
    @State private var items: [String] = []
    @State private var imageItems: [RankleItem] = []
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var isCollaborative: Bool = false
    @State private var selectedColor: Color = .cyan
    private let storage = StorageService()

    var onCreate: (String, [String], Color, Bool) -> Void
    var onCreateWithItems: ((String, [RankleItem], Color, Bool) -> Void)?
    var isTierList: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField(isTierList ? "e.g., Favorite Games" : "e.g., Favorite Movies", text: $name)
                }
                Section("Icon Color") {
                    ColorPicker("Color", selection: $selectedColor, supportsOpacity: false)
                }
                if !isTierList {
                    Section("Collaboration") {
                        Toggle("Create as collaborative list", isOn: $isCollaborative)
                    }
                }
                Section("Add Items") {
                    HStack {
                        TextField("Item name", text: $currentItem)
                        Button("Add") {
                            let trimmed = currentItem.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            items.append(trimmed)
                            currentItem = ""
                        }
                        .buttonStyle(ThemeButtonStyle())
                        .disabled(currentItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
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
                            // Only process the first image (maxSelectionCount is 1, but handle array anyway)
                            if let itemProvider = newItems.first {
                                if let data = try? await itemProvider.loadTransferable(type: Data.self),
                                   let utType = itemProvider.supportedContentTypes.first {
                                    let ext = utType.preferredFilenameExtension ?? "jpg"
                                    if let filename = try? storage.saveMedia(data: data, fileExtension: ext) {
                                        let mediaItem = MediaItem(type: .image, filename: filename)
                                        // Only one image per item
                                        let rankleItem = RankleItem(title: "", media: [mediaItem])
                                        imageItems.append(rankleItem)
                                    }
                                }
                            }
                            selectedImages.removeAll()
                        }
                    }
                }
                Section("Items (\(items.count + imageItems.count))") {
                    if items.isEmpty && imageItems.isEmpty {
                        Text("No items yet")
                            .foregroundColor(.secondary)
                    } else {
                        // Combined list with indices
                        ForEach(0..<(items.count + imageItems.count), id: \.self) { index in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                
                                if index < items.count {
                                    // Text item
                                    Text(items[index])
                                } else {
                                    // Image item
                                    let imageIndex = index - items.count
                                    if imageIndex < imageItems.count {
                                        let item = imageItems[imageIndex]
                                        if let firstMedia = item.media.first,
                                           let uiImage = UIImage(contentsOfFile: storage.urlForMedia(filename: firstMedia.filename).path) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(systemName: "photo")
                                                .frame(width: 50, height: 50)
                                                .background(Color.gray.opacity(0.2))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        Text("Image")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            // Handle deletion by determining which items to delete
                            var itemsToDelete = Set<Int>()
                            for offset in offsets {
                                itemsToDelete.insert(offset)
                            }
                            
                            // Separate text and image deletions
                            var textOffsets = IndexSet()
                            var imageOffsets = IndexSet()
                            
                            for offset in offsets {
                                if offset < items.count {
                                    textOffsets.insert(offset)
                                } else {
                                    imageOffsets.insert(offset - items.count)
                                }
                            }
                            
                            // Delete text items (need to adjust indices if image items are deleted first)
                            if !textOffsets.isEmpty {
                                items.remove(atOffsets: textOffsets)
                            }
                            
                            // Delete image items
                            if !imageOffsets.isEmpty {
                                imageItems.remove(atOffsets: imageOffsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isTierList ? "New Tier List" : "New List")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // Combine text items and image items into RankleItems
                        var allItems: [RankleItem] = items.map { RankleItem(title: $0) }
                        allItems.append(contentsOf: imageItems)
                        
                        // Use new callback if available (supports image items), otherwise fall back to old one
                        if let onCreateWithItems = onCreateWithItems {
                            onCreateWithItems(name, allItems, selectedColor, isCollaborative)
                        } else {
                            // Fallback: convert to strings for backward compatibility
                            var textItems: [String] = items
                            for _ in imageItems {
                                // Use "Image" as placeholder title
                                textItems.append("Image")
                            }
                            onCreate(name, textItems, selectedColor, isCollaborative)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (items.isEmpty && imageItems.isEmpty))
                }
            }
        }
    }
}

#Preview {
    CreateListView(onCreate: { _, _, _, _ in })
}
