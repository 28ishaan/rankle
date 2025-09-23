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
                    .foregroundStyle(.green)
                Text("Ranking Complete")
                    .font(.title2)
                Button("Done") {
                    onComplete(viewModel.list)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else if let matchup = viewModel.currentMatchup {
                Text("Which do you prefer?")
                    .font(.headline)
                HStack(spacing: 16) {
                    ChoiceCard(title: matchup.left.title) {
                        viewModel.choose(.left)
                    }
                    ChoiceCard(title: matchup.right.title) {
                        viewModel.choose(.right)
                    }
                }
                .padding(.horizontal)
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
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Text(title)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
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
