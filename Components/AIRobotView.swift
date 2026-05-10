import SwiftUI

struct AIRobotView: View {
    @State private var eyeOffset: CGFloat = 0
    @State private var armRaise: CGFloat = 0
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        ZStack {
            // Base robot body
            RoundedRectangle(cornerRadius: 36)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .frame(width: 120, height: 150)
                .shadow(radius: 10)

            // Face plate
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.96))
                .frame(width: 90, height: 60)
                .offset(y: -24)

            // Eyes (move horizontally with gesture)
            HStack(spacing: 32) {
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .offset(x: eyeOffset)
                Circle()
                    .fill(Color.black)
                    .frame(width: 12, height: 12)
                    .offset(x: eyeOffset)
            }
            .offset(y: -30)

            // Smiling mouth
            ArcShape()
                .stroke(Color.pink, lineWidth: 2)
                .frame(width: 30, height: 12)
                .rotationEffect(.degrees(8))
                .offset(y: -12)

            // Left arm (raises on tap)
            Rectangle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 12, height: 50)
                .cornerRadius(6)
                .rotationEffect(.degrees(Double(-35) - Double(armRaise) * 30))
                .offset(x: -68, y: CGFloat(10) - armRaise * 28)
                .shadow(radius: 3)

            // Right arm (raises on tap)
            Rectangle()
                .fill(Color.purple.opacity(0.5))
                .frame(width: 12, height: 50)
                .cornerRadius(6)
                .rotationEffect(.degrees(Double(35) + Double(armRaise) * 30))
                .offset(x: 68, y: CGFloat(10) - armRaise * 28)
                .shadow(radius: 3)

            // Antenna
            Capsule()
                .fill(Color.yellow)
                .frame(width: 8, height: 36)
                .offset(y: -94)
                .shadow(radius: 2)

            // Head ball
            Circle()
                .fill(Color.yellow.opacity(0.85))
                .frame(width: 18, height: 18)
                .offset(y: -112)
                .shadow(radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Eyes follow horizontal drag
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let norm = max(-1, min(1, value.translation.width / 70))
                    eyeOffset = norm * 8
                }
                .onEnded { _ in
                    withAnimation(.spring()) { eyeOffset = 0 }
                }
        )
        // Arms raise on tap
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.35, blendDuration: 0.3)) {
                armRaise = 1
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55, blendDuration: 0.7).delay(0.32)) {
                armRaise = 0
            }
        }
        .allowsHitTesting(true)
    }
}

// Simple arc for robot mouth
struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        path.move(to: start)
        path.addQuadCurve(to: end, control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
