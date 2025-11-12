import SwiftUI

private struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct AddItemRankingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddItemRankingViewModel
    @State private var shareURL: ShareableURL?

    var onComplete: ([RankleItem]) -> Void
    let listId: UUID?
    let isCollaborative: Bool

    init(existingItems: [RankleItem], newItems: [RankleItem], listId: UUID? = nil, isCollaborative: Bool = false, onComplete: @escaping ([RankleItem]) -> Void) {
        _viewModel = StateObject(wrappedValue: AddItemRankingViewModel(existingItems: existingItems, newItems: newItems))
        self.listId = listId
        self.isCollaborative = isCollaborative
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.sunsetOrange)
                Text("Items Added!")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                if isCollaborative, let listId = listId {
                    Button {
                        let ranking = viewModel.getUpdatedList().map { $0.id }
                        if let url = SharingService.shared.generateContributionLink(
                            listId: listId,
                            userId: UserService.shared.currentUserId,
                            displayName: nil,
                            ranking: ranking
                        ) {
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
                    onComplete(viewModel.getUpdatedList())
                    dismiss()
                }
                .buttonStyle(ThemeButtonStyle())
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
                            
                            Text("(\(viewModel.processedCount + 1)/\(viewModel.totalCount))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(height: 60)
                        
                        // Question text
                        Text("Where should this item rank?")
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
                ProgressView("Preparing…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(item: $shareURL) { shareable in
            ShareSheet(activityItems: [shareable.url])
        }
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
    AddItemRankingView(existingItems: [], newItems: [RankleItem(title: "One"), RankleItem(title: "Two")]) { _ in }
}
