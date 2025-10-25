import SwiftUI
import AVKit

struct MediaCarouselView: View {
    let media: [MediaItem]
    private let storage = StorageService()

    var body: some View {
        TabView {
            ForEach(media) { item in
                if item.type == .image {
                    if let uiImage = UIImage(contentsOfFile: storage.urlForMedia(filename: item.filename).path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else {
                        placeholder
                    }
                } else {
                    VideoPlayer(player: AVPlayer(url: storage.urlForMedia(filename: item.filename)))
                        .scaledToFill()
                        .clipped()
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
    }

    private var placeholder: some View {
        ZStack {
            Color.black.opacity(0.2)
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    MediaCarouselView(media: [])
}
