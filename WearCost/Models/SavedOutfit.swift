import Foundation
import SwiftData
import SwiftUI

@Model
final class SavedOutfit {
    @Attribute(.unique) var id: UUID
    var name: String
    var occasion: String
    var createdAt: Date
    var lastWorn: Date?
    var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \WardrobeItem.outfits)
    var items: [WardrobeItem]? = []

    init(
        id: UUID = UUID(),
        name: String,
        occasion: String = "Casual",
        createdAt: Date = Date(),
        lastWorn: Date? = nil,
        notes: String? = nil,
        items: [WardrobeItem] = []
    ) {
        self.id = id
        self.name = name
        self.occasion = occasion
        self.createdAt = createdAt
        self.lastWorn = lastWorn
        self.notes = notes
        self.items = items
    }

    // MARK: - Computed Properties

    var totalCost: Double {
        items?.reduce(0.0) { $0 + $1.purchasePrice } ?? 0.0
    }

    var averageCPW: Double {
        guard let list = items, !list.isEmpty else { return 0.0 }
        let sum = list.reduce(0.0) { $0 + $1.costPerWear }
        return sum / Double(list.count)
    }

    var totalWearsCount: Int {
        items?.reduce(0) { $0 + $1.totalWears } ?? 0
    }

    var itemsCount: Int {
        items?.count ?? 0
    }

    /// Projected combined CPW drop if this entire outfit is worn today
    var combinedCPWDrop: Double {
        items?.reduce(0.0) { $0 + $1.cpwDropNextWear } ?? 0.0
    }

    // MARK: - One-Tap Log Action

    @discardableResult
    func logWear(in context: ModelContext, date: Date = Date()) -> Int {
        guard let list = items, !list.isEmpty else { return 0 }
        for item in list {
            let log = WearLog(loggedAt: date, item: item)
            context.insert(log)
        }
        self.lastWorn = date
        try? context.save()
        return list.count
    }
}
