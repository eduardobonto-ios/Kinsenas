import SwiftUI

struct FloatingSymbols: View {
    let symbols: [String]
    let baseColor: Color
    let count: Int
    let speedRange: ClosedRange<Double>
    let sizeRange: ClosedRange<CGFloat>

    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let size: CGFloat = .random(in: sizeRange)
                    let x = CGFloat.random(in: 0...geo.size.width)
                    let startY = geo.size.height + CGFloat.random(in: 10...180)
                    let endY: CGFloat = -CGFloat.random(in: 40...200)
                    let duration = Double.random(in: speedRange)
                    let delay = Double.random(in: 0.0...2.0)
                    let opacity = Double.random(in: 0.35...1.0)
                    let rotation = Double.random(in: -22...22)

                    Image(systemName: symbols[i % symbols.count])
                        .font(.system(size: size, weight: .semibold, design: .rounded))
                        .foregroundStyle(baseColor)
                        .opacity(animate ? 0.0 : opacity)
                        .position(x: x, y: animate ? endY : startY)
                        .rotationEffect(.degrees(animate ? rotation : 0))
                        .scaleEffect(animate ? CGFloat.random(in: 0.9...1.1) : 1.0)
                        .animation(
                            .easeInOut(duration: duration)
                                .repeatForever(autoreverses: false)
                                .delay(delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
