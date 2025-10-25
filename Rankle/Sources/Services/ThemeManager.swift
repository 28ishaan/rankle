import SwiftUI

final class ThemeManager: ObservableObject {
    @Published var colorScheme: ColorScheme = .light
    
    private let key = "app_color_scheme"
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: key),
           saved == "dark" {
            colorScheme = .dark
        }
    }
    
    func toggle() {
        colorScheme = colorScheme == .light ? .dark : .light
        UserDefaults.standard.set(colorScheme == .dark ? "dark" : "light", forKey: key)
    }
}

