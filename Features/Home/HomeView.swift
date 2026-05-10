import SwiftUI
import Combine

struct HomeView: View {

    @Binding var isLoading: Bool
    @StateObject var vm: HomeViewModel

    @State private var showChat = false
    @State private var keyboardHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geo in

            ZStack {

                // Background and subtle robot when not loading
                LinearGradient(
                    colors: [Color.orange.opacity(0.10), Color.yellow.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                AIRobotView()
                    .ignoresSafeArea()
                    .opacity(isLoading ? 0 : 0.18)

                // Main UI
                VStack(spacing: 10) {

                    Spacer(minLength: 1)

                    // HEADER
                    VStack(spacing: 0) {
                        AnimatedGradientText(text: "Kinsenas")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("budget app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 4)

                    // TABLE
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
                    .frame(maxHeight: geo.size.height * 0.55)
                    // Keyboard avoidance (match ExpensesView behavior)
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                    .onReceive(Publishers.keyboardHeight) { h in
                        // Avoid double-insetting with safe area
                        let safeBottom = geo.safeAreaInsets.bottom
                        keyboardHeight = max(0, h - safeBottom)
                    }

                    Divider()

                    // FOOTER
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 8)
                    )

                    Spacer(minLength: 8)
                }
                .padding(.horizontal)
                .opacity(isLoading ? 0 : 1)

                // Floating chat button — only when not loading
                if !isLoading {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()

                            AnimatedChatButton(action: { showChat = true })
                                .padding(.trailing, 20)
                                .padding(.bottom, 220) // above tab bar
                                .accessibilityLabel("Open Chat")
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }

                // Animated Loading Screen
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                        .zIndex(998)
                }
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            BudgetChatbotView(
                getRows: { vm.rows },
                getRemaining15: { vm.remainingAfter15th },
                getRemaining30: { vm.remainingAfter30th },
                getFirstCutoffDay: { vm.firstCutoffDay },
                getSecondCutoffDay: { vm.secondCutoffDay }
            )
        }
        .task {
            // Allow one frame for LoadingView content to render, then fade out.
            await MainActor.run { }
            withAnimation(.easeOut(duration: 0.3)) {
                isLoading = false
            }
        }
    }
}

// MARK: - Animated Chat Button (unchanged)
private struct AnimatedChatButton: View {
    let action: () -> Void

    @State private var rotate = false
    @State private var pulse = false
    @State private var shimmer = false

    private var palette: [Color] {
        [
            Color.gray.opacity(0.4),
            Color.yellow,
            Color.orange,
            Color.gray.opacity(0.4)
        ]
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: palette),
                            center: .center,
                            angle: .degrees(rotate ? 360 : 0)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 64, height: 64)
                    .opacity(0.95)
                    .animation(.linear(duration: 2.4).repeatForever(autoreverses: false), value: rotate)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.28),
                                Color.orange.opacity(0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 44
                        )
                    )
                    .frame(width: 64, height: 64)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.4),
                                Color.yellow,
                                Color.orange,
                                Color.gray.opacity(0.4)
                            ],
                            startPoint: shimmer ? .leading : .trailing,
                            endPoint: shimmer ? .trailing : .leading
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: shimmer)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.55),
                                .white.opacity(0.0)
                            ],
                            startPoint: shimmer ? .leading : .trailing,
                            endPoint: shimmer ? .trailing : .leading
                        )
                        .mask(
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.title2)
                        )
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: shimmer)
                    }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            rotate = true
            pulse = true
            shimmer = true
        }
        .accessibilityAddTraits(.isButton)
    }
}
