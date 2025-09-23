import SwiftUI
import PhotosUI

struct ItemDetailView: View {
    let listId: UUID
    @State var item: RankleItem
    var onUpdate: (RankleItem) -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    private let storage = StorageService()

    var body: some View {
        List {
            Section("Add Media") {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Select Photos/Videos")
                    }
                }
                .onChange(of: pickerItems) { newItems in
                    Task {
                        for itemProvider in newItems {
                            if let data = try? await itemProvider.loadTransferable(type: Data.self), let utType = itemProvider.supportedContentTypes.first {
                                let ext = utType.preferredFilenameExtension ?? "dat"
                                if let filename = try? storage.saveMedia(data: data, fileExtension: ext) {
                                    let type: MediaItem.MediaType = utType.conforms(to: .movie) ? .video : .image
                                    item.media.append(MediaItem(type: type, filename: filename))
                                }
                            }
                        }
                        pickerItems.removeAll()
                        onUpdate(item)
                    }
                }
            }
            Section("Media") {
                if item.media.isEmpty {
                    Text("No media yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(item.media) { media in
                        HStack {
                            Image(systemName: media.type == .video ? "video" : "photo")
                                .foregroundStyle(.secondary)
                            Text(media.filename)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .onDelete { offsets in
                        item.media.remove(atOffsets: offsets)
                        onUpdate(item)
                    }
                }
            }
        }
        .navigationTitle(item.title)
    }
}

#Preview {
    ItemDetailView(listId: UUID(), item: RankleItem(title: "Sample")) { _ in }
}
