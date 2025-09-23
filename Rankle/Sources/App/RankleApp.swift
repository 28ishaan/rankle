import SwiftUI

@main
struct RankleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(.system(.body, design: .rounded))
                .tint(.white)
                .preferredColorScheme(.dark)
                .background(Color(navyBackground))
                .environment(\.colorScheme, .dark)
        }
    }
}

private let navyBackground = UIColor(red: 7/255, green: 16/255, blue: 39/255, alpha: 1)
