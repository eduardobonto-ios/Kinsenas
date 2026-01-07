import SwiftUI

struct ExpensesView: View {

    @StateObject private var vm = ExpensesViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {

                // BACKGROUND (match HomeView gradient)
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

                    // HEADER (consistent with HomeView’s style block)
                    VStack(spacing: 0) {
                        AnimatedGradientText(text: "Expenses")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("track your spending")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 4)

                    // Month Selector
                    HStack(spacing: 12) {
                        Button {
                            vm.goToPreviousMonth()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)

                        Text(vm.selectedMonthTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)

                        Button {
                            vm.goToNextMonth()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    )

                    // SCROLLABLE TABLE AREA (same pattern as HomeView)
                    ScrollView {
                        ExpensesTableView(
                            rows: $vm.rows,
                            onAddRow: { vm.addRow() },
                            onRemoveRow: { vm.removeLastRow() },
                            onAmountChanged: { vm.recalculateTotal() }
                        )
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: geo.size.height * 0.55)

                    Divider()

                    // FOOTER (styled like HomeView "Remaining")
                    HStack(spacing: 12) {
                        Text("Total Expenses")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Single trailing amount, align similar to HomeView columns
                        Text("₱\(vm.totalExpenses, specifier: "%.0f")")
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
            }
        }
    }
}

// MARK: - Expenses Table (mirrors BudgetTableView look)
private struct ExpensesTableView: View {

    @Binding var rows: [ExpensesRow]

    let onAddRow: () -> Void
    let onRemoveRow: () -> Void
    let onAmountChanged: () -> Void

    private var fieldWidth: CGFloat { 120 }

    // Reuse same 3D field style from BudgetTableView via the same modifier type
    private func textField3D() -> some ViewModifier {
        Modifier3DField()
    }

    var body: some View {
        VStack(spacing: 12) {

            // Header row (styled subtly like BudgetTableView’s header section)
            HStack(spacing: 12) {
                Text("Description")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)

                Text("Amount")
                    .frame(width: fieldWidth, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Divider()

            // Rows
            ForEach($rows) { $row in
                HStack(spacing: 12) {

                    TextField("Expense", text: $row.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(textField3D())

                    TextField("0", text: $row.amount)
                        .keyboardType(.decimalPad)
                        .frame(width: fieldWidth, alignment: .trailing)
                        .onChange(of: row.amount) { _ in
                            onAmountChanged()
                        }
                        .modifier(textField3D())
                }
            }

            // Add / Remove Row Buttons (same visual pattern)
            HStack(spacing: 12) {
                Button(action: onAddRow) {
                    Label("Add Row", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onRemoveRow) {
                    Label("Remove Row", systemImage: "minus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(rows.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
                .shadow(color: .white.opacity(0.7), radius: 1, x: -1, y: -1)
        )
    }
}

