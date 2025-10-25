import SwiftUI

struct ContentView: View {
    @ObservedObject var listsViewModel: ListsViewModel
    @State private var showSplash = true

    var body: some View {
        ZStack {
            HomeView(viewModel: listsViewModel)
                .opacity(showSplash ? 0 : 1)
                .offset(x: showSplash ? UIScreen.main.bounds.width * 0.15 : 0)
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView(listsViewModel: ListsViewModel())
}
