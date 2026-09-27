import AppIntents
import SwiftData
import Foundation

struct LogWearIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Item Wear"
    static var description = IntentDescription("Increments wear count for a specified item.")

    @Parameter(title: "Item ID")
    var targetItemID: String

    init() {}

    init(itemID: UUID) {
        self.targetItemID = itemID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: targetItemID) else {
            return .result()
        }

        let container = try ModelContainer(for: WardrobeItem.self, WearLog.self)
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<WardrobeItem>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1

        if let item = try context.fetch(descriptor).first {
            let log = WearLog(loggedAt: Date(), item: item)
            context.insert(log)
            try context.save()
        }

        return .result()
    }
}

struct WearCostShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWearIntent(),
            phrases: [
                "Log wear in \(.applicationName)",
                "Wear outfit in \(.applicationName)"
            ],
            shortTitle: "Log Wear",
            systemImageName: "plus.circle.fill"
        )
    }
}
