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
        VStack(spacing: 24) {
            if viewModel.isComplete {
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
            } else if let matchup = viewModel.currentMatchup {
                Text("Which do you prefer?")
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
                if viewModel.canGoBack() {
                    Button {
                        viewModel.goBack()
                    } label: {
                        HStack {
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
            } else {
                ProgressView("Preparing matchups…")
            }
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
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
    RankingView(list: RankleList(name: "Sample", items: ["A","B","C","D"].map { RankleItem(title: $0) })) { _ in }
}
