import SwiftUI

struct ThemeButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        let primaryColor = Color.themePrimary(colorScheme)
        let gradientColors = colorScheme == .dark 
            ? [Color.nightYellow, Color.nightYellow.opacity(0.8)]
            : [Color.sunsetOrange, Color.sunsetPink]
        
        configuration.label
            .font(.custom("Avenir Next", size: 16))
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: primaryColor.opacity(0.3), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
