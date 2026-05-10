import SwiftUI

struct TikTokTabBar: View {

    @Binding var selectedTab: ContentView.Tab

    var body: some View {
        HStack(spacing: 48) {
            tabItem(
                icon: "house.fill",
                title: "Kinsenas",
                tab: .home
            )

            tabItem(
                icon: "clock.arrow.circlepath",
                title: "Expenses",
                tab: .expenses
            )
        }
        .frame(maxWidth: .infinity) // center the pair of items
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

