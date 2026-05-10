import SwiftUI

struct ContentView: View {

    @State private var selectedTab: Tab = .home
    @State private var isHomeLoading: Bool = true
    @StateObject private var homeVM = HomeViewModel()

    enum Tab {
        case home
        case expenses
        // Removed: case history
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // MAIN CONTENT
            Group {
                switch selectedTab {
                case .home:
                    HomeView(isLoading: $isHomeLoading, vm: homeVM)

                case .expenses:
                    ExpensesView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }
            }
            .ignoresSafeArea()

            // ✅ TAB BAR EXISTS ONLY AFTER LOADING
            if !isHomeLoading {
                TikTokTabBar(selectedTab: $selectedTab)
            }
        }
    }
}
