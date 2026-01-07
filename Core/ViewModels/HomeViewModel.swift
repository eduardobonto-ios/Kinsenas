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
            BudgetRow(name: "Salary", firstCutoff: "26000", secondCutoff: "27000"),
            BudgetRow(name: "Housing Loan", firstCutoff: "6000", secondCutoff: "6000"),
            BudgetRow(name: "Autoloan", firstCutoff: "8000", secondCutoff: "8000"),
            BudgetRow(name: "HMO", firstCutoff: "1157", secondCutoff: "1157"),
            BudgetRow(name: "Savings", firstCutoff: "5000", secondCutoff: "5000")
        ]
    }

    // MARK: - Persistence (Rows)
    private func loadRows() {
        guard
            let data = UserDefaults.standard.data(forKey: rowsKey),
            let decoded = try? JSONDecoder().decode([BudgetRow].self, from: data)
        else {
            // First install → seed defaults
            rows = defaultRows
            return
        }

        rows = decoded
    }

    private func saveRows() {
        guard let encoded = try? JSONEncoder().encode(rows) else { return }
        UserDefaults.standard.set(encoded, forKey: rowsKey)
    }

    // MARK: - Persistence (Cutoff Days)
    private func loadCutoffDays() {
        // Use stored values if available; otherwise keep defaults (15 and 30)
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
        // Clamp values to 1...31 for safety, then save
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
        // Protect Salary row
        guard rows.count > 1 else { return }
        rows.removeLast()
    }

    // MARK: - Totals
    var monthlyTotalValue: Double {
        rows.reduce(0.0) { total, row in
            total
            + (Double(row.firstCutoff) ?? 0)
            + (Double(row.secondCutoff) ?? 0)
        }
    }

    var remainingAfter15th: Double {
        guard let salaryRow = rows.first else { return 0 }

        let salary = Double(salaryRow.firstCutoff) ?? 0

        let expenses = rows.dropFirst().reduce(0.0) { total, row in
            total + (Double(row.firstCutoff) ?? 0)
        }

        return salary - expenses
    }

    var remainingAfter30th: Double {
        guard let salaryRow = rows.first else { return 0 }

        let salary = Double(salaryRow.secondCutoff) ?? 0

        let expenses = rows.dropFirst().reduce(0.0) { total, row in
            total + (Double(row.secondCutoff) ?? 0)
        }

        return salary - expenses
    }

}
