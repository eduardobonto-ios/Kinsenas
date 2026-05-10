import Foundation

struct ExpensesRow: Identifiable, Codable {
    let id: UUID
    var name: String
    var amount: String
    var date: Date // NEW

    init(id: UUID = UUID(), name: String = "", amount: String = "", date: Date = Date()) {
        self.id = id
        self.name = name
        self.amount = amount
        self.date = date
    }

    var amountValue: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }
}

// Backward compatible decoding for older saved data without `date`
extension ExpensesRow {
    enum CodingKeys: String, CodingKey {
        case id, name, amount, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(amount, forKey: .amount)
        try c.encode(date, forKey: .date)
    }
}
