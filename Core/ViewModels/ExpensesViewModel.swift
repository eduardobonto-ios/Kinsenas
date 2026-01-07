import SwiftUI
import Combine

final class ExpensesViewModel: ObservableObject {

    // MARK: - Keys
    private let storeKey = "expenses.byMonth" // JSON dictionary of monthKey -> [ExpensesRow]

    // MARK: - Month selection
    @Published var selectedMonth: Date {
        didSet {
            loadRowsForSelectedMonth()
        }
    }

    // Exposed rows for the currently selected month
    @Published var rows: [ExpensesRow] = [] {
        didSet {
            saveRowsForSelectedMonth()
        }
    }

    // Backing store: monthKey -> [ExpensesRow]
    private var allMonthRows: [String: [ExpensesRow]] = [:]

    // MARK: - Init
    init() {
        // Normalize to first day of current month
        let now = Date()
        self.selectedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
        loadAll()
        loadRowsForSelectedMonth()
    }

    // MARK: - Month Navigation
    func goToPreviousMonth() {
        guard let newDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return }
        selectedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: newDate)) ?? newDate
    }

    func goToNextMonth() {
        guard let newDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) else { return }
        selectedMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: newDate)) ?? newDate
    }

    var selectedMonthTitle: String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy" // e.g., January 2026
        return df.string(from: selectedMonth)
    }

    private func monthKey(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM" // stable key
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: date)
    }

    // MARK: - Persistence
    private func loadAll() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let decoded = try? JSONDecoder().decode([String: [ExpensesRow]].self, from: data)
        else {
            allMonthRows = [:]
            return
        }
        allMonthRows = decoded
    }

    private func saveAll() {
        guard let encoded = try? JSONEncoder().encode(allMonthRows) else { return }
        UserDefaults.standard.set(encoded, forKey: storeKey)
    }

    private func loadRowsForSelectedMonth() {
        let key = monthKey(for: selectedMonth)
        rows = allMonthRows[key] ?? defaultRowsForEmptyMonth()
    }

    private func saveRowsForSelectedMonth() {
        let key = monthKey(for: selectedMonth)
        allMonthRows[key] = rows
        saveAll()
    }

    private func defaultRowsForEmptyMonth() -> [ExpensesRow] {
        [
            ExpensesRow(name: "Food", amount: ""),
            ExpensesRow(name: "Transportation", amount: "")
        ]
    }

    // MARK: - Computed Total
    var totalExpenses: Double {
        rows.reduce(0) { $0 + $1.amountValue }
    }

    // MARK: - Actions
    func addRow() {
        rows.append(ExpensesRow())
    }

    func removeRow(at offsets: IndexSet) {
        rows.remove(atOffsets: offsets)
    }

    func recalculateTotal() {
        // total is computed from rows
    }

    func removeLastRow() {
        guard rows.count > 0 else { return }
        rows.removeLast()
    }
}

