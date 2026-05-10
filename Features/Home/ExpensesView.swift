import SwiftUI
import Combine

struct ExpensesView: View {

    @StateObject private var vm = ExpensesViewModel()
    @State private var keyboardHeight: CGFloat = 0

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

                    // SCROLLABLE TABLE AREA
                    ScrollView {
                        ExpensesTableView(
                            rows: $vm.rows,
                            onAddRow: { vm.addRow() },
                            onRemoveRow: { vm.removeLastRow() },
                            onAmountChanged: { vm.recalculateTotal() }
                        )
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxHeight: geo.size.height * 0.55)
                    // Keyboard avoidance: add bottom inset equal to keyboard height
                    .padding(.bottom, keyboardHeight)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                    .onReceive(Publishers.keyboardHeight) { h in
                        // Account for safe area bottom so we don't double inset
                        let safeBottom = geo.safeAreaInsets.bottom
                        keyboardHeight = max(0, h - safeBottom)
                    }

                    Divider()

                    // FOOTER
                    HStack(spacing: 12) {
                        Text("Total Expenses")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("₱\(vm.totalExpenses, specifier: "%.0f")")
                            .fontWeight(.bold)
                            .font(.system(.title3, design: .rounded))
                            .frame(width: 120, alignment: .trailing)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
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
        // Remove keyboard ignoring so the inset above can take effect
        // .ignoresSafeArea(.keyboard, edges: .bottom) // removed
    }
}

// MARK: - Expenses Table (mirrors BudgetTableView look)
private struct ExpensesTableView: View {

    @Binding var rows: [ExpensesRow]

    let onAddRow: () -> Void
    let onRemoveRow: () -> Void
    let onAmountChanged: () -> Void

    // Column widths
    private var amountWidth: CGFloat { 80 }  // reduced to avoid right-side overlap
    private var dateWidth: CGFloat { 90 }    // reduced to avoid right-side overlap
    private var minDescriptionWidth: CGFloat { 120 }

    // Track which row is editing date
    @State private var editingDateRowID: UUID? = nil

    // Focus handling (tap to dismiss like Kinsenas)
    enum Field: Hashable {
        case name(UUID)
        case amount(UUID)
    }
    @FocusState private var focusedField: Field?

    // Reuse same 3D field style from BudgetTableView
    private func textField3D() -> some ViewModifier {
        Modifier3DField()
    }

    // Thousands formatter (same logic used in BudgetTableView)
    private func formatThousands(_ s: String) -> String {
        let digits = s.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        let n = Double(digits) ?? 0
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? digits
    }

    // Date formatter MM/dd/yyyy
    private static let df: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yyyy"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    var body: some View {
        VStack(spacing: 12) {

            // Header row
            HStack(spacing: 12) {
                Text("Description")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: minDescriptionWidth, maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)

                Text("Amount")
                    .frame(width: amountWidth, alignment: .trailing)
                    .foregroundColor(.secondary)

                Text("Date")
                    .frame(width: dateWidth, alignment: .center)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Divider()

            // Rows
            ForEach($rows) { $row in
                HStack(spacing: 12) {

                    // Description
                    TextField("Expense", text: $row.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: minDescriptionWidth, maxWidth: .infinity, alignment: .leading)
                        .modifier(textField3D())
                        .focused($focusedField, equals: .name(row.id))

                    // Amount with thousands separator
                    TextField("0", text: $row.amount)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .textContentType(.oneTimeCode)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: amountWidth, alignment: .trailing)
                        .onChange(of: row.amount) {
                            row.amount = formatThousands(row.amount)
                            onAmountChanged()
                        }
                        .modifier(textField3D())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .focused($focusedField, equals: .amount(row.id))

                    // Date: show only formatted text; tap opens a sheet with a DatePicker
                    Button {
                        editingDateRowID = row.id
                    } label: {
                        Text(Self.df.string(from: row.date))
                            // Use default .body to match Description and Amount
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .frame(width: dateWidth, alignment: .center)
                    .modifier(textField3D())
                    .sheet(isPresented: Binding(
                        get: { editingDateRowID != nil },
                        set: { newValue in
                            if !newValue { editingDateRowID = nil }
                        }
                    )) {
                        if let id = editingDateRowID,
                           let idx = rows.firstIndex(where: { $0.id == id }) {
                            DateEditorSheet(date: $rows[idx].date) {
                                editingDateRowID = nil
                            }
                        } else {
                            DateEditorSheet(date: .constant(Date())) {
                                editingDateRowID = nil
                            }
                        }
                    }
                }
            }

            // Add / Remove Row Buttons
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
        .frame(maxWidth: .infinity, alignment: .leading)
        // Dismiss keyboard on background tap (match Kinsenas behavior)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
    }
}

// MARK: - Date editor sheet
private struct DateEditorSheet: View {
    @Binding var date: Date
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select date",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()

                Spacer()
            }
            .navigationTitle("Choose Date")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                }
            }
        }
    }
}
