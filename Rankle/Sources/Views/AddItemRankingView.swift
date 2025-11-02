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
                Text("Where should this item rank? (") + Text("\(viewModel.processedCount + 1)/\(viewModel.totalCount)") + Text(")")
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack(spacing: 16) {
                    ChoiceCard(item: matchup.left) {
                        viewModel.choose(.left)
                    }
                    ChoiceCard(item: matchup.right) {
                        viewModel.choose(.right)
                    }
                }
                .padding(.horizontal)
            } else {
                ProgressView("Preparing…")
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if !item.media.isEmpty {
                    MediaCarouselView(media: item.media)
                        .frame(height: 200)
                }
                Text(item.title)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .shadow(radius: 1)
    }
}

#Preview {
    AddItemRankingView(existingItems: [], newItems: [RankleItem(title: "One"), RankleItem(title: "Two")]) { _ in }
}
