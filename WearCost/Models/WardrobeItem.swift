import Foundation
import SwiftData
import SwiftUI

public enum GarmentCategory: String, CaseIterable, Identifiable, Codable {
    case tops = "Tops"
    case bottoms = "Bottoms"
    case footwear = "Footwear"
    case outerwear = "Outerwear"
    case accessories = "Accessories"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .tops:
            return "tshirt.fill"
        case .bottoms:
            return "figure.walk"
        case .footwear:
            return "shoe.fill"
        case .outerwear:
            return "jacket.fill"
        case .accessories:
            return "eyeglasses"
        }
    }

    public var color: Color {
        switch self {
        case .tops:
            return .blue
        case .bottoms:
            return .indigo
        case .footwear:
            return .orange
        case .outerwear:
            return .purple
        case .accessories:
            return .teal
        }
    }
}

public enum CPWUtilityTier: String {
    case high = "High Utility"
    case moderate = "Moderate Utility"
    case low = "Low Utility"

    public var color: Color {
        switch self {
        case .high:
            return .green
        case .moderate:
            return .orange
        case .low:
            return .red
        }
    }

    public var iconName: String {
        switch self {
        case .high:
            return "checkmark.circle.fill"
        case .moderate:
            return "exclamationmark.triangle.fill"
        case .low:
            return "flame.fill"
        }
    }

    @MainActor
    public var thresholdDescription: String {
        thresholdDescription(with: CurrencyManager.shared, thresholds: ThresholdManager.shared)
    }

    @MainActor
    public func thresholdDescription(with manager: CurrencyManager, thresholds: ThresholdManager) -> String {
        thresholds.thresholdDescription(for: self, currency: manager)
    }

    @MainActor
    public func thresholdDescription(with manager: CurrencyManager) -> String {
        thresholdDescription(with: manager, thresholds: ThresholdManager.shared)
    }
}

@Model
final class WardrobeItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var purchasePrice: Double
    var datePurchased: Date
    @Attribute(.externalStorage) var imageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \WearLog.item)
    var wearLogs: [WearLog]? = []

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        purchasePrice: Double,
        datePurchased: Date = Date(),
        imageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.purchasePrice = purchasePrice
        self.datePurchased = datePurchased
        self.imageData = imageData
    }

    // Dynamic Computed Properties
    var totalWears: Int {
        wearLogs?.count ?? 0
    }

    var costPerWear: Double {
        guard let wears = wearLogs, !wears.isEmpty else {
            return purchasePrice
        }
        return purchasePrice / Double(wears.count)
    }

    var garmentCategory: GarmentCategory {
        GarmentCategory(rawValue: category) ?? .tops
    }

    @MainActor
    var utilityTier: CPWUtilityTier {
        ThresholdManager.shared.tier(for: costPerWear)
    }

    /// Calculates wears needed to reach a target CPW
    func wearsNeeded(forTargetCPW target: Double) -> Int {
        guard target > 0 else { return 0 }
        let requiredTotal = Int(ceil(purchasePrice / target))
        return max(0, requiredTotal - totalWears)
    }

    /// Next target milestone based on current CPW
    @MainActor
    var nextMilestone: (targetCPW: Double, wearsNeeded: Int, progress: Double)? {
        let tm = ThresholdManager.shared
        let targets: [Double] = [
            tm.moderateThreshold,
            (tm.moderateThreshold + tm.highThreshold) / 2.0,
            tm.highThreshold,
            max(0.5, tm.highThreshold / 2.0)
        ].sorted(by: >)

        for target in targets {
            if costPerWear > target {
                let needed = wearsNeeded(forTargetCPW: target)
                let baseline = purchasePrice > target ? purchasePrice : target * 2.0
                let delta = max(1.0, baseline - target)
                let achieved = baseline - costPerWear
                let currentProgress = min(1.0, max(0.0, achieved / delta))
                return (targetCPW: target, wearsNeeded: needed, progress: currentProgress)
            }
        }
        return nil
    }
}

@Model
final class WearLog {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var item: WardrobeItem?

    init(id: UUID = UUID(), loggedAt: Date = Date(), item: WardrobeItem? = nil) {
        self.id = id
        self.loggedAt = loggedAt
        self.item = item
    }
}
