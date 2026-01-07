import SwiftUI

struct ContentView: View {

    @State private var selectedTab: Tab = .home
    @State private var isHomeLoading: Bool = true

    enum Tab {
        case home
        case expenses
        case history
        case profile
    }


    var body: some View {
        ZStack(alignment: .bottom) {

            // MAIN CONTENT
            Group {
                switch selectedTab {
                case .home:
                    HomeView(isLoading: $isHomeLoading)

                case .expenses:
                    ExpensesView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))

                case .history:
                    Text("History")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))

                case .profile:
                    Text("Profile")
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
