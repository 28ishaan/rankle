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
        }
        .listRowBackground(Color.clear)
        .navigationTitle(item.title)
    }
}

#Preview {
    ItemDetailView(listId: UUID(), item: RankleItem(title: "Sample")) { _ in }
}
