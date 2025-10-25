import SwiftUI

struct AddItemRankingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddItemRankingViewModel

    var onComplete: ([RankleItem]) -> Void

    init(existingItems: [RankleItem], newItems: [RankleItem], onComplete: @escaping ([RankleItem]) -> Void) {
        _viewModel = StateObject(wrappedValue: AddItemRankingViewModel(existingItems: existingItems, newItems: newItems))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Items Added!")
                    .font(.title2)
                    .foregroundColor(.white)
                Button("Done") {
                    onComplete(viewModel.getUpdatedList())
                    dismiss()
                }
                .buttonStyle(ThemeButtonStyle())
            } else if let matchup = viewModel.currentMatchup {
                Text("Where should this item rank? (") + Text("\(viewModel.processedCount + 1)/\(viewModel.totalCount)") + Text(")")
                    .font(.headline)
                    .foregroundColor(.white)
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
    }
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
