import SwiftUI

struct AnimatedGradientText: View {

    let text: String

    @State private var animate = false

    var body: some View {
        Text(text)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.4),
                        Color.yellow,
                        Color.orange,
                        Color.gray.opacity(0.4)
                    ],
                    startPoint: animate ? .leading : .trailing,
                    endPoint: animate ? .trailing : .leading
                )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.6)
                    .repeatForever(autoreverses: false)
                ) {
                    animate.toggle()
                }
            }
    }
}
