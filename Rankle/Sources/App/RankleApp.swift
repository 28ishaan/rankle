import SwiftUI

@main
struct RankleApp: App {
    @StateObject private var listsViewModel = ListsViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(listsViewModel: listsViewModel)
                .font(.system(.body, design: .rounded))
                .tint(.white)
                .preferredColorScheme(.dark)
                .background(Color(navyBackground))
                .environment(\.colorScheme, .dark)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        if let list = SharingService.shared.parseDeepLink(url: url) {
            listsViewModel.importList(list)
        }
    }
}

private let navyBackground = UIColor(red: 7/255, green: 16/255, blue: 39/255, alpha: 1)
