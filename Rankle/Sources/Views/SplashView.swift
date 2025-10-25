import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.sunsetGradientTop, .sunsetGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("R")
                    .font(.custom("Avenir Next", size: 72))
                    .fontWeight(.heavy)
                    .foregroundColor(.sunsetOrange)
                    .padding(24)
                    .background(Circle().fill(.white))
                    .shadow(color: .sunsetOrange.opacity(0.4), radius: 12)
                Text("Rankle")
                    .font(.custom("Avenir Next", size: 44))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Rank what you love")
                    .font(.custom("Avenir Next", size: 16))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SplashView()
}
