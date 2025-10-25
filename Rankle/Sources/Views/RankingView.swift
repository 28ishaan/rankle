import SwiftUI

struct RankingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RankingViewModel

    var onComplete: (RankleList) -> Void

    init(list: RankleList, onComplete: @escaping (RankleList) -> Void) {
        _viewModel = StateObject(wrappedValue: RankingViewModel(list: list))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            if viewModel.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Ranking Complete")
                    .font(.title2)
                    .foregroundColor(.white)
                Button("Done") {
                    onComplete(viewModel.list)
                    dismiss()
                }
                .buttonStyle(ThemeButtonStyle())
            } else if let matchup = viewModel.currentMatchup {
                Text("Which do you prefer?")
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
                if viewModel.canGoBack() {
                    Button {
                        viewModel.goBack()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
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
    RankingView(list: RankleList(name: "Sample", items: ["A","B","C","D"].map { RankleItem(title: $0) })) { _ in }
}
