import SwiftUI

struct LoadingView: View {
    @State private var showLogo = false

    var body: some View {
        ZStack {
            // Match HomeView background to avoid white flash
            LinearGradient(
                colors: [Color.orange.opacity(0.10), Color.yellow.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Centered animated app name
            AnimatedGradientText(text: "Kinsenas")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Loading Kinsenas")

            // Bottom-centered logo/icon (deferred to next runloop to avoid blocking first frame)
            VStack {
                Spacer()
                if showLogo {
                    Image("KinsenasLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                } else {
                    // Reserve space so layout is stable even before logo appears
                    Color.clear
                        .frame(width: 72, height: 72)
                        .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .task {
            // Defer logo to next tick so the first frame shows text immediately
            await MainActor.run { }
            withAnimation(.easeIn(duration: 0.2)) { showLogo = true }
        }
    }
}
