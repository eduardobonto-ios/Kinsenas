import Foundation

struct BudgetRow: Identifiable, Codable {
    let id: UUID
    var name: String
    var firstCutoff: String
    var secondCutoff: String

    init(
        id: UUID = UUID(),
        name: String,
        firstCutoff: String,
        secondCutoff: String
    ) {
        self.id = id
        self.name = name
        self.firstCutoff = firstCutoff
        self.secondCutoff = secondCutoff
    }

    // ✅ ADD THIS
    var isEssential: Bool {
        let n = name.lowercased()
        return n.contains("loan") ||
               n.contains("mortgage") ||
               n.contains("rent") ||
               n.contains("insurance") ||
               n.contains("tuition") ||
               n.contains("electric") ||
               n.contains("water")
    }
}
