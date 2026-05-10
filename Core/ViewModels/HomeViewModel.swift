import Foundation
import Combine

final class HomeViewModel: ObservableObject {

    // MARK: - Keys
    private let rowsKey = "kinsenas.rows"
    private let firstCutoffKey = "kinsenas.firstCutoffDay"
    private let secondCutoffKey = "kinsenas.secondCutoffDay"

    // MARK: - Published State
    @Published var rows: [BudgetRow] = [] {
        didSet {
            saveRows()
        }
    }

    @Published var firstCutoffDay: Int = 15 {
        didSet {
            saveCutoffDays()
        }
    }
    @Published var secondCutoffDay: Int = 30 {
        didSet {
            saveCutoffDays()
        }
    }

    // MARK: - Init
    init() {
        loadRows()
        loadCutoffDays()
    }

    // MARK: - Default Seed (First Launch Only)
    private var defaultRows: [BudgetRow] {
        [
            BudgetRow(name: "Net Salary", firstCutoff: "26,000", secondCutoff: "27,000"),
            BudgetRow(name: "Savings", firstCutoff: "5,000", secondCutoff: "5,000"),
            BudgetRow(name: "Emergency fund", firstCutoff: "2,000", secondCutoff: "2,000"),
            BudgetRow(name: "Housing Loan", firstCutoff: "6,000", secondCutoff: "6,000"),
            BudgetRow(name: "Autoloan", firstCutoff: "8,000", secondCutoff: "8,000"),
            BudgetRow(name: "HMO", firstCutoff: "1,157", secondCutoff: "1,157")
        ]
    }

    // MARK: - Persistence (Rows)
    private func loadRows() {
        guard
            let data = UserDefaults.standard.data(forKey: rowsKey),
            let decoded = try? JSONDecoder().decode([BudgetRow].self, from: data)
        else {
            // First install → seed defaults (already formatted)
            rows = defaultRows
            return
        }

        var migrated = decoded

        // 1) Rename old "Salary" to "Net Salary"
        if !migrated.isEmpty && migrated[0].name.lowercased() == "salary" {
            migrated[0].name = "Net Salary"
        }

        // Helper to find and remove first row matching name (case-insensitive)
        func takeRow(named target: String) -> BudgetRow? {
            if let idx = migrated.firstIndex(where: { $0.name.lowercased() == target.lowercased() }) {
                return migrated.remove(at: idx)
            }
            return nil
        }

        // 2) Ensure index 0 is Net Salary
        if migrated.isEmpty {
            migrated.insert(BudgetRow(name: "Net Salary", firstCutoff: "0", secondCutoff: "0"), at: 0)
        } else if migrated[0].name.lowercased() != "net salary" {
            if let net = takeRow(named: "Net Salary") ?? takeRow(named: "Salary") {
                migrated.insert(net, at: 0)
            } else {
                migrated.insert(BudgetRow(name: "Net Salary", firstCutoff: "0", secondCutoff: "0"), at: 0)
            }
        }

        // 3) Ensure index 1 is Savings
        if migrated.count < 2 {
            migrated.append(BudgetRow(name: "Savings", firstCutoff: "5,000", secondCutoff: "5,000"))
        }
        if migrated[1].name.lowercased() != "savings" {
            if let savings = takeRow(named: "savings") {
                migrated.insert(savings, at: 1)
            } else {
                migrated.insert(BudgetRow(name: "Savings", firstCutoff: "5,000", secondCutoff: "5,000"), at: 1)
            }
        }

        // 4) Ensure index 2 is Emergency fund
        if migrated.count < 3 {
            migrated.append(BudgetRow(name: "Emergency fund", firstCutoff: "2,000", secondCutoff: "2,000"))
        }
        if migrated[2].name.lowercased() != "emergency fund" {
            if let ef = takeRow(named: "emergency fund") ?? takeRow(named: "emergency") {
                migrated.insert(ef, at: 2)
            } else {
                migrated.insert(BudgetRow(name: "Emergency fund", firstCutoff: "2,000", secondCutoff: "2,000"), at: 2)
            }
        }

        // 5) Format first three rows' amounts with thousands separators
        func formatThousands(_ s: String) -> String {
            let digits = s.filter { $0.isNumber }
            guard !digits.isEmpty else { return "" }
            let n = Double(digits) ?? 0
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            f.groupingSeparator = ","
            return f.string(from: NSNumber(value: n)) ?? digits
        }

        for i in 0..<min(3, migrated.count) {
            migrated[i].firstCutoff  = formatThousands(migrated[i].firstCutoff)
            migrated[i].secondCutoff = formatThousands(migrated[i].secondCutoff)
        }

        rows = migrated
    }

    private func saveRows() {
        guard let encoded = try? JSONEncoder().encode(rows) else { return }
        UserDefaults.standard.set(encoded, forKey: rowsKey)
    }

    // MARK: - Persistence (Cutoff Days)
    private func loadCutoffDays() {
        let storedFirst = UserDefaults.standard.object(forKey: firstCutoffKey) as? Int
        let storedSecond = UserDefaults.standard.object(forKey: secondCutoffKey) as? Int

        if let first = storedFirst, (1...31).contains(first) {
            firstCutoffDay = first
        }
        if let second = storedSecond, (1...31).contains(second) {
            secondCutoffDay = second
        }
    }

    private func saveCutoffDays() {
        let first = max(1, min(31, firstCutoffDay))
        let second = max(1, min(31, secondCutoffDay))

        UserDefaults.standard.set(first, forKey: firstCutoffKey)
        UserDefaults.standard.set(second, forKey: secondCutoffKey)
    }

    // MARK: - Row Actions
    func addRow() {
        rows.append(
            BudgetRow(name: "", firstCutoff: "", secondCutoff: "")
        )
    }

    func removeLastRow() {
        // Protect first three fixed rows: Net Salary, Savings, Emergency fund
        guard rows.count > 3 else { return }
        rows.removeLast()
    }

    // MARK: - Helpers
    private var incomeRow: BudgetRow? {
        rows.first // Net Salary is fixed as first row
    }

    private var nonIncomeExpenseRows: ArraySlice<BudgetRow> {
        rows.dropFirst().filter { row in
            let n = row.name.lowercased()
            return !(n == "savings" || n == "emergency fund")
        }[...]
    }

    // MARK: - Totals
    var monthlyTotalValue: Double {
        rows.reduce(0.0) { total, row in
            total
            + (Double(row.firstCutoff.replacingOccurrences(of: ",", with: "")) ?? 0)
            + (Double(row.secondCutoff.replacingOccurrences(of: ",", with: "")) ?? 0)
        }
    }

    var remainingAfter15th: Double {
        guard let salaryRow = incomeRow else { return 0 }

        let salary = Double(salaryRow.firstCutoff.replacingOccurrences(of: ",", with: "")) ?? 0

        let expenses = nonIncomeExpenseRows.reduce(0.0) { total, row in
            total + (Double(row.firstCutoff.replacingOccurrences(of: ",", with: "")) ?? 0)
        }

        return salary - expenses
    }

    var remainingAfter30th: Double {
        guard let salaryRow = incomeRow else { return 0 }

        let salary = Double(salaryRow.secondCutoff.replacingOccurrences(of: ",", with: "")) ?? 0

        let expenses = nonIncomeExpenseRows.reduce(0.0) { total, row in
            total + (Double(row.secondCutoff.replacingOccurrences(of: ",", with: "")) ?? 0)
        }

        return salary - expenses
    }

}
