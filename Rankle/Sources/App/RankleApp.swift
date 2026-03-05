import SwiftUI
import CloudKit
import UserNotifications

// MARK: - App Delegate
// Needed to receive CloudKit silent push notifications via the standard APNs remote
// notification path. SwiftUI's .onContinueUserActivity does NOT handle CloudKit pushes —
// those are delivered through didReceiveRemoteNotification:fetchCompletionHandler:.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request permission so the OS will deliver silent pushes for CloudKit subscriptions.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
        return true
    }

    // Called for both foreground and background silent pushes (including CloudKit subscription triggers).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationCenter.default.post(name: .cloudKitPushNotification, object: nil)
        completionHandler(.newData)
    }
}

@main
struct RankleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
