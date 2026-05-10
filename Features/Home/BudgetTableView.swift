import SwiftUI

struct BudgetTableView: View {

    @Binding var rows: [BudgetRow]
    @Binding var firstCutoffDay: Int
    @Binding var secondCutoffDay: Int

    let onAddRow: () -> Void
    let onRemoveRow: () -> Void

    // MARK: - Focus
    enum BudgetField: Hashable {
        case name(UUID)
        case first(UUID)
        case second(UUID)
    }
    @FocusState private var focusedField: BudgetField?

    // MARK: - Styles
    private var fieldWidth: CGFloat { 90 }

    private func textField3D() -> some ViewModifier {
        Modifier3DField()
    }

    private func pillPickerStyle() -> some ViewModifier {
        ModifierPill()
    }

    // MARK: - Ordinal formatting
    private func ordinalString(for day: Int) -> String {
        let suffix: String
        let ones = day % 10
        let tens = (day / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    private func isFixedRow(_ index: Int) -> Bool {
        index < 3 // 0: Net Salary, 1: Savings, 2: Emergency fund
    }

    // MARK: - Formatting
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

    var body: some View {
        VStack(spacing: 12) {

            // HEADER WITH DROPDOWNS
            HStack(spacing: 12) {
                Text("Cut-off")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.secondary)

                Picker("", selection: $firstCutoffDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text(ordinalString(for: day)).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: fieldWidth)
                .modifier(pillPickerStyle())

                Picker("", selection: $secondCutoffDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text(ordinalString(for: day)).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: fieldWidth)
                .modifier(pillPickerStyle())
            }
            .font(.caption)

            Divider()

            // ROWS
            ForEach(Array($rows.enumerated()), id: \.element.id) { index, $row in
                HStack(spacing: 12) {

                    if isFixedRow(index) {
                        let color: Color = {
                            switch index {
                            case 0: return .green
                            case 1: return .blue
                            default: return .teal
                            }
                        }()

                        Text(row.name)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(textField3D())
                    } else {
                        TextField("Name", text: $row.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(textField3D())
                            .focused($focusedField, equals: .name(row.id))
                    }

                    TextField("0", text: $row.firstCutoff)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .textContentType(.oneTimeCode)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80, alignment: .trailing)
                        .onChange(of: row.firstCutoff) {
                            row.firstCutoff = formatThousands(row.firstCutoff)
                        }
                        .modifier(textField3D())
                        .focused($focusedField, equals: .first(row.id))

                    TextField("0", text: $row.secondCutoff)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .textContentType(.oneTimeCode)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80, alignment: .trailing)
                        .onChange(of: row.secondCutoff) {
                            row.secondCutoff = formatThousands(row.secondCutoff)
                        }
                        .modifier(textField3D())
                        .focused($focusedField, equals: .second(row.id))
                }
            }

            // ADD / REMOVE ROW BUTTONS
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
                .disabled(rows.count <= 3)
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
        // Dismiss keyboard on background tap using FocusState
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - 3D Field Modifier
struct Modifier3DField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: -1, y: -1)
            )
    }
}

// MARK: - Pill Picker Modifier
struct ModifierPill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 1, x: -1, y: -1)
            )
    }
}
