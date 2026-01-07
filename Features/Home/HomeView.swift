import SwiftUI

struct HomeView: View {

    @Binding var isLoading: Bool
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // BACKGROUND
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground),
                        Color(.secondarySystemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    Spacer(minLength: 1)

                    // =========================
                    // HEADER (SAFE + HIGHER)
                    // =========================
                    VStack(spacing: 0) {
                        AnimatedGradientText(text: "Kinsenas")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("budget app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    // Push just below speaker / Dynamic Island
                    .padding(.top, geo.safeAreaInsets.top + 4)

                    // =========================
                    // SCROLLABLE TABLE AREA
                    // =========================
                    ScrollView {
                        BudgetTableView(
                            rows: $vm.rows,
                            firstCutoffDay: $vm.firstCutoffDay,
                            secondCutoffDay: $vm.secondCutoffDay,
                            onAddRow: { vm.addRow() },
                            onRemoveRow: { vm.removeLastRow() }
                        )


                        .padding(.vertical, 4)
                        
                    }
                    .scrollIndicators(.visible)
                    // Constrain height so footer stays visible
                    .frame(
                        maxHeight: geo.size.height * 0.55
                    )

                    Divider()

                    // =========================
                    // FOOTER (FIXED)
                    // =========================
                    HStack(spacing: 12) {
                        Text("Remaining")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("₱\(vm.remainingAfter15th, specifier: "%.0f")")
                            .fontWeight(.bold)
                            .frame(width: 90, alignment: .trailing)

                        Text("₱\(vm.remainingAfter30th, specifier: "%.0f")")
                            .fontWeight(.bold)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    )

                    Spacer(minLength: 8)
                }
                .padding(.horizontal)
                .opacity(isLoading ? 0 : 1)

                // =========================
                // LOADING SCREEN
                // =========================
                if isLoading {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()

                        AnimatedGradientText(text: "Kinsenas")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.easeOut(duration: 0.25)) {
                    isLoading = false
                }
            }
        }
    }
}
