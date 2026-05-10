import SwiftUI

struct GradientIcon: View {
    let systemName: String
    let isSelected: Bool

    // Matches AnimatedGradientText palette for visual consistency
    private var selectedGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.gray.opacity(0.4),
                Color.yellow,
                Color.orange,
                Color.gray.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical) // good default for SF Symbols
            .foregroundStyle(isSelected ? AnyShapeStyle(selectedGradient) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        GradientIcon(systemName: "house.fill", isSelected: true)
            .frame(width: 26, height: 26)
        GradientIcon(systemName: "house.fill", isSelected: false)
            .frame(width: 26, height: 26)
    }
    .padding()
}
