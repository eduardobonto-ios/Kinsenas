import SwiftUI

struct TikTokTabBar: View {

    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack {

            tabItem(
                icon: "house.fill",
                title: "Kinsenas",
                tab: .home
            )

            Spacer()

            tabItem(
                icon: "clock.arrow.circlepath",
                title: "Expenses",
                tab: .expenses
            )


            Spacer()

            tabItem(
                icon: "person.fill",
                title: "Profile",
                tab: .profile
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.08), radius: 6, y: -2)
        )
    }

    // MARK: - Tab Item
    private func tabItem(
        icon: String,
        title: String,
        tab: ContentView.Tab
    ) -> some View {

        let isSelected = (selectedTab == tab)

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                GradientIcon(
                    systemName: icon,
                    isSelected: isSelected
                )
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3D Gradient Icon (masked by actual SF Symbol)
private struct GradientIcon: View {
    let systemName: String
    var isSelected: Bool = true

    var body: some View {
        ZStack {
            // 1) Soft drop shadow, masked by the symbol so it matches the shape
            shadowLayer
                .mask(symbolMask)

            // 2) Main gradient fill, masked by the symbol
            gradientFill
                .mask(symbolMask)

            // 3) Inner highlight to simulate bevel/shine, masked by the symbol
            highlightLayer
                .mask(symbolMask)
        }
        .compositingGroup()
        .accessibilityHidden(true)
    }

    // MARK: - Mask
    private var symbolMask: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .font(.system(size: 100, weight: .regular)) // ensures SF Symbol uses default weight
            .symbolRenderingMode(.monochrome)
    }

    // MARK: - Layers
    private var shadowLayer: some View {
        ZStack {
            // Outer soft shadow
            LinearGradient(
                colors: [
                    .black.opacity(isSelected ? 0.18 : 0.10),
                    .black.opacity(isSelected ? 0.10 : 0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blur(radius: isSelected ? 1.2 : 1.0)
            .offset(y: isSelected ? 1.2 : 1.0)
        }
    }

    private var gradientFill: some View {
        Group {
            if isSelected {
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.99, green: 0.23, blue: 0.43), // pink
                        Color(red: 0.98, green: 0.54, blue: 0.22), // orange
                        Color(red: 0.98, green: 0.86, blue: 0.23), // yellow
                        Color(red: 0.27, green: 0.86, blue: 0.46), // green
                        Color(red: 0.25, green: 0.64, blue: 0.98), // blue
                        Color(red: 0.58, green: 0.43, blue: 0.98), // purple
                        Color(red: 0.99, green: 0.23, blue: 0.43)  // back to pink
                    ]),
                    center: .center
                )
                .saturation(1.05)
                .brightness(0.02)
            } else {
                LinearGradient(
                    colors: [
                        Color.secondary.opacity(0.85),
                        Color.secondary.opacity(0.55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var highlightLayer: some View {
        ZStack {
            // Top-left highlight simulated by a light gradient and slight blur
            LinearGradient(
                colors: [
                    .white.opacity(isSelected ? 0.9 : 0.6),
                    .white.opacity(isSelected ? 0.15 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .opacity(isSelected ? 0.9 : 0.5)
            .blur(radius: isSelected ? 0.6 : 0.4)
        }
    }
}
