import SwiftUI
import CloudKit

@main
struct RankleApp: App {
    @StateObject private var listsViewModel = ListsViewModel()
    @StateObject private var themeManager = ThemeManager()
    
    init() {
        // Set up CloudKit push notifications
        let container = CKContainer.default()
        container.privateCloudDatabase.fetchAllSubscriptions { subscriptions, error in
            #if DEBUG
            if let error = error {
                print("Error fetching subscriptions: \(error)")
            }
            #endif
        }
    }
    
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
                .onContinueUserActivity("com.apple.CloudKit.push", perform: handleCloudKitPush)
        }
    }
    
    private func handleCloudKitPush(_ userActivity: NSUserActivity) {
        // Post notification to trigger sync
        NotificationCenter.default.post(name: .cloudKitPushNotification, object: nil)
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
