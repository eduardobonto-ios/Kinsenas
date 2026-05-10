import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Centered animated app name
            AnimatedGradientText(text: "Kinsenas")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Loading Kinsenas")

            // Bottom-centered logo/icon
            VStack {
                Spacer()
                Image("KinsenasLogo") // replace with your actual asset name
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72) // adjust as needed
                    .accessibilityHidden(true)
                    .padding(.bottom, 40) // space above the bottom edge
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
