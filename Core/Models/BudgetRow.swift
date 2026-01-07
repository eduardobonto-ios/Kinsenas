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
}
