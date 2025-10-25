import SwiftUI

extension Color {
    // Light Mode - Sunset Color Palette
    static let sunsetCreme = Color(red: 255/255, green: 250/255, blue: 240/255)
    static let sunsetOrange = Color(red: 255/255, green: 159/255, blue: 102/255)
    static let sunsetPink = Color(red: 255/255, green: 184/255, blue: 184/255)
    static let sunsetBlue = Color(red: 173/255, green: 216/255, blue: 230/255)
    static let sunsetPurple = Color(red: 203/255, green: 153/255, blue: 201/255)
    static let sunsetGold = Color(red: 255/255, green: 215/255, blue: 117/255)
    
    // Dark Mode - Nighttime Color Palette
    static let nightDarkGray = Color(red: 30/255, green: 30/255, blue: 30/255)
    static let nightLightGray = Color(red: 60/255, green: 60/255, blue: 60/255)
    static let nightYellow = Color(red: 255/255, green: 215/255, blue: 100/255)
    static let nightWhite = Color(red: 240/255, green: 240/255, blue: 240/255)
    
    // Adaptive colors based on color scheme
    static func themePrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .nightYellow : .sunsetOrange
    }
    
    static func themeBackground(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark 
            ? [nightDarkGray, nightLightGray, nightDarkGray]
            : [sunsetGradientTop, sunsetGradientMid, sunsetGradientBottom]
    }
    
    static func themeDetailBackground(_ scheme: ColorScheme) -> [Color] {
        scheme == .dark
            ? [nightLightGray, nightDarkGray]
            : [detailGradientTop, detailGradientBottom]
    }
    
    static func themeRowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark 
            ? nightLightGray.opacity(0.7)
            : sunsetCreme.opacity(0.85)
    }
    
    // Rich background gradients (Light Mode)
    static let sunsetGradientTop = Color(red: 255/255, green: 183/255, blue: 147/255)
    static let sunsetGradientMid = Color(red: 255/255, green: 218/255, blue: 185/255)
    static let sunsetGradientBottom = Color(red: 255/255, green: 239/255, blue: 213/255)
    
    // Detail page gradient (Light Mode)
    static let detailGradientTop = Color(red: 255/255, green: 200/255, blue: 165/255)
    static let detailGradientBottom = Color(red: 255/255, green: 235/255, blue: 205/255)
    
    // Accent colors for lists
    static let sunsetAccents: [Color] = [
        .sunsetOrange,
        .sunsetPink,
        .sunsetBlue,
        .sunsetPurple,
        .sunsetGold,
        Color(red: 255/255, green: 200/255, blue: 124/255), // Peach
    ]
}

