import SwiftUI

@main
struct RankleApp: App {
    @StateObject private var listsViewModel = ListsViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView(listsViewModel: listsViewModel)
                .font(.custom("Avenir Next", size: 17))
                .tint(Color.themePrimary(themeManager.colorScheme))
                .preferredColorScheme(themeManager.colorScheme)
                .environmentObject(themeManager)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        // Contribution link
        if let contribution = SharingService.shared.parseContribution(url: url) {
            let ranking = CollaboratorRanking(userId: contribution.userId, displayName: contribution.displayName, ranking: contribution.ranking)
            listsViewModel.upsertContribution(listId: contribution.listId, ranking: ranking)
            return
        }
        // List import link
        if let list = SharingService.shared.parseDeepLink(url: url) {
            listsViewModel.importList(list)
        }
    }
}
