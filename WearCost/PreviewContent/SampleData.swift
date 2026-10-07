import Foundation
import SwiftData
import UIKit
import SwiftUI

@MainActor
struct SampleData {
    static func createSampleContainer() -> ModelContainer {
        let schema = Schema([WardrobeItem.self, WearLog.self, SavedOutfit.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            insertSampleItems(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create sample ModelContainer: \(error)")
        }
    }

    static func insertSampleItems(into context: ModelContext) {
        let itemsData: [(name: String, category: GarmentCategory, price: Double, wears: Int, daysAgo: Int)] = [
            ("Raw Denim Jacket", .outerwear, 180.0, 45, 120),
            ("White Oxford Shirt", .tops, 65.0, 38, 90),
            ("Slim Chino Pants", .bottoms, 85.0, 52, 160),
            ("Leather Chelsea Boots", .footwear, 220.0, 115, 300),
            ("Cashmere Knit Sweater", .tops, 150.0, 12, 60),
            ("Running Sneakers", .footwear, 130.0, 70, 150),
            ("Wool Overcoat", .outerwear, 320.0, 18, 200),
            ("Canvas Tote Bag", .accessories, 35.0, 60, 100),
            ("Merino Beanie", .accessories, 40.0, 22, 80),
            ("Linen Summer Shorts", .bottoms, 55.0, 8, 45)
        ]

        let calendar = Calendar.current
        let now = Date()
        var insertedItems: [WardrobeItem] = []

        for itemInfo in itemsData {
            let purchaseDate = calendar.date(byAdding: .day, value: -itemInfo.daysAgo, to: now) ?? now
            let item = WardrobeItem(
                name: itemInfo.name,
                category: itemInfo.category.rawValue,
                purchasePrice: itemInfo.price,
                datePurchased: purchaseDate,
                imageData: createPlaceholderImageData(symbolName: itemInfo.category.iconName, tintColor: itemInfo.category.color)
            )
            context.insert(item)
            insertedItems.append(item)

            if itemInfo.wears > 0 {
                let interval = max(1, itemInfo.daysAgo / itemInfo.wears)
                for i in 0..<itemInfo.wears {
                    let wearDate = calendar.date(byAdding: .day, value: -(i * interval), to: now) ?? now
                    let log = WearLog(loggedAt: wearDate, item: item)
                    context.insert(log)
                }
            }
        }

        // Create initial Lookbook combos
        if let oxford = insertedItems.first(where: { $0.name == "White Oxford Shirt" }),
           let chinos = insertedItems.first(where: { $0.name == "Slim Chino Pants" }),
           let boots = insertedItems.first(where: { $0.name == "Leather Chelsea Boots" }) {
            let officeOutfit = SavedOutfit(
                name: "Office Formal",
                occasion: "Work",
                createdAt: calendar.date(byAdding: .day, value: -30, to: now) ?? now,
                lastWorn: calendar.date(byAdding: .day, value: -2, to: now),
                notes: "Sharp, clean pairing for boardroom and weekly sprint demos.",
                items: [oxford, chinos, boots]
            )
            context.insert(officeOutfit)
        }

        if let denim = insertedItems.first(where: { $0.name == "Raw Denim Jacket" }),
           let oxford = insertedItems.first(where: { $0.name == "White Oxford Shirt" }),
           let chinos = insertedItems.first(where: { $0.name == "Slim Chino Pants" }),
           let sneakers = insertedItems.first(where: { $0.name == "Running Sneakers" }),
           let tote = insertedItems.first(where: { $0.name == "Canvas Tote Bag" }) {
            let casualOutfit = SavedOutfit(
                name: "Weekend Casual",
                occasion: "Casual",
                createdAt: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                lastWorn: calendar.date(byAdding: .day, value: -5, to: now),
                notes: "Effortless weekend uniform for coffee runs and casual strolls.",
                items: [denim, oxford, chinos, sneakers, tote]
            )
            context.insert(casualOutfit)
        }

        if let coat = insertedItems.first(where: { $0.name == "Wool Overcoat" }),
           let cashmere = insertedItems.first(where: { $0.name == "Cashmere Knit Sweater" }),
           let chinos = insertedItems.first(where: { $0.name == "Slim Chino Pants" }),
           let boots = insertedItems.first(where: { $0.name == "Leather Chelsea Boots" }),
           let beanie = insertedItems.first(where: { $0.name == "Merino Beanie" }) {
            let chillyOutfit = SavedOutfit(
                name: "Chilly Commute",
                occasion: "Cold Weather",
                createdAt: calendar.date(byAdding: .day, value: -15, to: now) ?? now,
                lastWorn: calendar.date(byAdding: .day, value: -10, to: now),
                notes: "Layered warmth maximizing high-investment outerwear ROI.",
                items: [coat, cashmere, chinos, boots, beanie]
            )
            context.insert(chillyOutfit)
        }

        try? context.save()
    }

    private static func createPlaceholderImageData(symbolName: String, tintColor: SwiftUI.Color) -> Data? {
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 36)
            UIColor.systemGray6.setFill()
            path.fill()

            let config = UIImage.SymbolConfiguration(pointSize: 110, weight: .regular)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: config) {
                let tinted = symbol.withTintColor(UIColor(tintColor), renderingMode: .alwaysOriginal)
                let symbolRect = CGRect(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2,
                    width: symbol.size.width,
                    height: symbol.size.height
                )
                tinted.draw(in: symbolRect)
            }
        }
        return image.pngData()
    }
}
