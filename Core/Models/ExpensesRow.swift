import Foundation

struct ExpensesRow: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: String

    init(id: UUID = UUID(), name: String = "", amount: String = "") {
        self.id = id
        self.name = name
        self.amount = amount
    }

    var amountValue: Double {
        Double(amount) ?? 0
    }
}
