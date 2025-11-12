import SwiftUI

private struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct RankingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RankingViewModel
    @State private var shareURL: ShareableURL?

    var onComplete: (RankleList) -> Void
    private let originalList: RankleList

    init(list: RankleList, onComplete: @escaping (RankleList) -> Void) {
        _viewModel = StateObject(wrappedValue: RankingViewModel(list: list))
        self.originalList = list
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            if viewModel.isComplete {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.sunsetOrange)
                    Text("Ranking Complete")
                        .font(.title2)
                        .foregroundColor(.primary)
                    
                    if originalList.isCollaborative {
                        Button {
                            if let url = generateContributionURL() {
                                shareURL = ShareableURL(url: url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Contribution")
                            }
                        }
                        .buttonStyle(ThemeButtonStyle())
                    }
                    
                    Button("Done") {
                        onComplete(viewModel.list)
                        dismiss()
                    }
                    .buttonStyle(ThemeButtonStyle())
                }
                .padding()
            } else if let matchup = viewModel.currentMatchup {
                GeometryReader { geometry in
                    let availableHeight = geometry.size.height - 122 // 60 (nav) + 40 (question) + 22 (divider)
                    let cardHeight = max(100.0, availableHeight / 2.0)
                    
                    VStack(spacing: 0) {
                        // Top navigation bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            if viewModel.canGoBack() {
                                Button {
                                    viewModel.goBack()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.left")
                                        Text("Back")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.sunsetOrange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding()
                        .frame(height: 60)
                        
                        // Question text
                        Text("Which do you prefer?")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.vertical, 8)
                            .frame(height: 40)
                        
                        // Top choice (full width, half height minus spacing)
                        ChoiceCard(item: matchup.left, position: .top) {
                            viewModel.choose(.left)
                        }
                        .frame(height: cardHeight)
                        .clipped()
                        
                        // Divider with solid background to prevent overlap
                        ZStack {
                            // Use system background with slight padding to ensure full coverage
                            Color(UIColor.systemBackground)
                                .frame(height: 22)
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                                Text("OR")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 22)
                        .zIndex(100)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, y: -1)
                        
                        // Bottom choice (full width, half height minus spacing)
                        ChoiceCard(item: matchup.right, position: .bottom) {
                            viewModel.choose(.right)
                        }
                        .frame(height: cardHeight)
                        .clipped()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView("Preparing matchups…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $shareURL) { shareable in
            ShareSheet(activityItems: [shareable.url])
        }
    }
    
    private func generateContributionURL() -> URL? {
        guard originalList.isCollaborative else { return nil }
        let ranking = viewModel.list.items.map { $0.id }
        return SharingService.shared.generateContributionLink(
            listId: originalList.id,
            userId: UserService.shared.currentUserId,
            displayName: nil,
            ranking: ranking
        )
    }
}

// SwiftUI wrapper for UIActivityViewController
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ChoiceCard: View {
    let item: RankleItem
    var position: CardPosition
    var action: () -> Void
    
    @State private var storage = StorageService()
    
    enum CardPosition {
        case top
        case bottom
    }
    
    private var hasImage: Bool {
        !item.media.isEmpty && item.media.first?.type == .image
    }
    
    private var image: UIImage? {
        guard let firstMedia = item.media.first,
              firstMedia.type == .image else { return nil }
        return UIImage(contentsOfFile: storage.urlForMedia(filename: firstMedia.filename).path)
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { cardGeometry in
                ZStack {
                    // Background
                    Color.secondary.opacity(0.05)
                    
                    VStack(spacing: 0) {
                        // Show image prominently if available
                        if hasImage, let uiImage = image {
                            ZStack {
                                // Black background to fill the space
                                Color.black
                                    .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
                                
                                // Image with preserved aspect ratio
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: cardGeometry.size.width, maxHeight: cardGeometry.size.height)
                                    .contentShape(Rectangle())
                            }
                        } else if !item.media.isEmpty {
                            // For videos, use carousel (but should only have one item now)
                            ZStack {
                                // Black background for videos
                                Color.black
                                    .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
                                
                                MediaCarouselView(media: item.media)
                                    .frame(maxWidth: cardGeometry.size.width, maxHeight: cardGeometry.size.height)
                            }
                        }
                        
                        // Show title if it exists, or if no media
                        if !item.title.isEmpty || item.media.isEmpty {
                            VStack {
                                if item.title.isEmpty && !item.media.isEmpty {
                                    Text("Image")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                } else {
                                    Text(item.title)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(item.media.isEmpty ? .primary : .white)
                                        .shadow(color: item.media.isEmpty ? .clear : .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.7), Color.black.opacity(0.3), Color.clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                        }
                    }
                    .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
                    .clipped()
                    
                    // Border overlay
                    Rectangle()
                        .stroke(position == .top ? Color.blue.opacity(0.4) : Color.green.opacity(0.4), lineWidth: 3)
                }
                .frame(width: cardGeometry.size.width, height: cardGeometry.size.height)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RankingView(list: RankleList(name: "Sample", items: ["A","B","C","D"].map { RankleItem(title: $0) })) { _ in }
}
