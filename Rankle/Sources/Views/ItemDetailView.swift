import SwiftUI
import PhotosUI

struct MediaRowView: View {
    let media: MediaItem
    let storage: StorageService
    
    var body: some View {
        HStack {
            if media.type == .image {
                if let imageData = storage.loadMedia(filename: media.filename),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo")
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Image(systemName: "video")
                    .frame(width: 60, height: 60)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(media.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(media.type == .video ? "Video" : "Photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ItemDetailView: View {
    let listId: UUID
    @State var item: RankleItem
    var onUpdate: (RankleItem) -> Void
    var isCollaborative: Bool = false

    @State private var pickerItems: [PhotosPickerItem] = []
    private let storage = StorageService()

    private var hasImage: Bool {
        item.media.contains { $0.type == .image }
    }
    
    var body: some View {
        List {
            if !isCollaborative {
                Section("Add Media") {
                    if hasImage {
                        Text("This item already has an image. Only one image per item is allowed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 1, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Add Image")
                            }
                        }
                        .onChange(of: pickerItems) { newItems in
                            Task {
                                // Only process the first item (maxSelectionCount is 1)
                                if let itemProvider = newItems.first {
                                    if let data = try? await itemProvider.loadTransferable(type: Data.self),
                                       let utType = itemProvider.supportedContentTypes.first {
                                        let ext = utType.preferredFilenameExtension ?? "jpg"
                                        if let filename = try? storage.saveMedia(data: data, fileExtension: ext) {
                                            // Only one image allowed - replace if exists, otherwise append
                                            if let existingImageIndex = item.media.firstIndex(where: { $0.type == .image }) {
                                                item.media[existingImageIndex] = MediaItem(type: .image, filename: filename)
                                            } else {
                                                item.media.append(MediaItem(type: .image, filename: filename))
                                            }
                                            onUpdate(item)
                                        }
                                    }
                                }
                                pickerItems.removeAll()
                            }
                        }
                    }
                }
                
                Section("Media") {
                    if item.media.isEmpty {
                        Text("No media yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(item.media) { media in
                            MediaRowView(media: media, storage: storage)
                        }
                        .onDelete { offsets in
                            item.media.remove(atOffsets: offsets)
                            onUpdate(item)
                        }
                    }
                }
            } else {
                Section("Media") {
                    Text("Media is not available for collaborative lists")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listRowBackground(Color.clear)
        .navigationTitle(item.title.isEmpty && !item.media.isEmpty ? "Image" : item.title)
    }
}

#Preview {
    ItemDetailView(listId: UUID(), item: RankleItem(title: "Sample"), onUpdate: { _ in }, isCollaborative: false)
}
