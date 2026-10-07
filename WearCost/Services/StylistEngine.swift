import Foundation
import SwiftUI
import SwiftData
import FoundationModels
import Combine

struct StylistRecommendation: Identifiable, Equatable {
    let id: UUID
    var weather: DailyWeatherReport
    var suggestedItems: [WardrobeItem]
    var heroItem: WardrobeItem?
    var heroDropAmount: Double
    var heroHeadline: String
    var combinedCPWDrop: Double
    var stylistAdvice: String
    var outfitTitle: String
    var occasionTag: String

    init(
        id: UUID = UUID(),
        weather: DailyWeatherReport,
        suggestedItems: [WardrobeItem],
        heroItem: WardrobeItem?,
        heroDropAmount: Double,
        heroHeadline: String,
        combinedCPWDrop: Double,
        stylistAdvice: String,
        outfitTitle: String,
        occasionTag: String
    ) {
        self.id = id
        self.weather = weather
        self.suggestedItems = suggestedItems
        self.heroItem = heroItem
        self.heroDropAmount = heroDropAmount
        self.heroHeadline = heroHeadline
        self.combinedCPWDrop = combinedCPWDrop
        self.stylistAdvice = stylistAdvice
        self.outfitTitle = outfitTitle
        self.occasionTag = occasionTag
    }
}

@MainActor
final class StylistEngine: ObservableObject {
    static let shared = StylistEngine()

    @Published private(set) var currentRecommendation: StylistRecommendation?
    @Published private(set) var isGeneratingAdvice: Bool = false
    @Published private(set) var lastGeneratedDate: Date?

    private var shuffleSeed: Int = 0

    private init() {}

    // MARK: - Generate Weather & CPW-Optimized Outfit

    func generateRecommendation(
        for items: [WardrobeItem],
        weather: DailyWeatherReport,
        currencyManager: CurrencyManager = .shared
    ) {
        guard !items.isEmpty else {
            currentRecommendation = nil
            return
        }

        // 1. Group items by category
        let tops = items.filter { $0.category == GarmentCategory.tops.rawValue }
        let bottoms = items.filter { $0.category == GarmentCategory.bottoms.rawValue }
        let footwear = items.filter { $0.category == GarmentCategory.footwear.rawValue }
        let outerwear = items.filter { $0.category == GarmentCategory.outerwear.rawValue }
        let accessories = items.filter { $0.category == GarmentCategory.accessories.rawValue }

        // 2. Score candidates in each category
        var pickedItems: [WardrobeItem] = []

        if let bestTop = pickBestCandidate(from: tops, category: .tops, weather: weather) {
            pickedItems.append(bestTop)
        }

        if let bestBottom = pickBestCandidate(from: bottoms, category: .bottoms, weather: weather) {
            pickedItems.append(bestBottom)
        }

        if let bestShoes = pickBestCandidate(from: footwear, category: .footwear, weather: weather) {
            pickedItems.append(bestShoes)
        }

        // Outerwear decision: Cold, freezing, mild, or raining
        let shouldIncludeOuterwear = weather.temperatureFahrenheit < 68 || weather.isRaining
        if shouldIncludeOuterwear, let bestOuter = pickBestCandidate(from: outerwear, category: .outerwear, weather: weather) {
            pickedItems.append(bestOuter)
        }

        // Accessories decision: Cold -> beanie/scarf; Sunny/Warm -> glasses/bag
        if let bestAccessory = pickBestCandidate(from: accessories, category: .accessories, weather: weather) {
            pickedItems.append(bestAccessory)
        }

        // If items were scarce across categories, grab top CPW drop items overall
        if pickedItems.isEmpty {
            pickedItems = Array(items.sorted(by: { $0.cpwDropNextWear > $1.cpwDropNextWear }).prefix(3))
        }

        // 3. Find the Hero CPW Piece
        let sortedByDrop = pickedItems.sorted(by: { $0.cpwDropNextWear > $1.cpwDropNextWear })
        let hero = sortedByDrop.first
        let heroDrop = hero?.cpwDropNextWear ?? 0.0

        let formattedDrop = currencyManager.format(heroDrop)
        let heroHeadline: String
        if let hero = hero {
            heroHeadline = "Wear your \(hero.name) today to drop its CPW by \(formattedDrop)"
        } else {
            heroHeadline = "Wear today's outfit to accelerate your CPW milestones"
        }

        let combinedDrop = pickedItems.reduce(0.0) { $0 + $1.cpwDropNextWear }

        // Determine title and occasion
        let titleAndOccasion = determineTitleAndOccasion(weather: weather, picked: pickedItems)

        let initialAdvice = generateFallbackStylistAdvice(
            weather: weather,
            picked: pickedItems,
            hero: hero,
            heroDrop: formattedDrop
        )

        let rec = StylistRecommendation(
            weather: weather,
            suggestedItems: pickedItems,
            heroItem: hero,
            heroDropAmount: heroDrop,
            heroHeadline: heroHeadline,
            combinedCPWDrop: combinedDrop,
            stylistAdvice: initialAdvice,
            outfitTitle: titleAndOccasion.title,
            occasionTag: titleAndOccasion.occasion
        )

        self.currentRecommendation = rec
        self.lastGeneratedDate = Date()

        // 4. Optionally enrich with Apple AI FoundationModels
        Task {
            await enrichAdviceWithFoundationModels(rec: rec, weather: weather, hero: hero, heroDrop: formattedDrop)
        }
    }

    func shuffleRecommendation(
        for items: [WardrobeItem],
        weather: DailyWeatherReport,
        currencyManager: CurrencyManager = .shared
    ) {
        shuffleSeed += 1
        generateRecommendation(for: items, weather: weather, currencyManager: currencyManager)
    }

    // MARK: - Candidate Scoring Engine

    private func pickBestCandidate(
        from pool: [WardrobeItem],
        category: GarmentCategory,
        weather: DailyWeatherReport
    ) -> WardrobeItem? {
        guard !pool.isEmpty else { return nil }

        let scored = pool.map { item -> (item: WardrobeItem, score: Double) in
            var score = 0.0

            // 1. CPW Optimization Priority
            score += item.cpwDropNextWear * 4.0

            // Low utility tier priority
            if item.utilityTier == .low {
                score += 35.0
            } else if item.utilityTier == .moderate {
                score += 15.0
            }

            // Unworn penalty / priority: Prioritize items with 0 wears
            if item.totalWears == 0 {
                score += 40.0
            } else if item.totalWears < 5 {
                score += 20.0
            }

            // High initial purchase price prioritization
            score += min(50.0, item.purchasePrice * 0.15)

            // 2. Weather Suitability
            let lowerName = item.name.lowercased()

            switch category {
            case .outerwear:
                if weather.temperatureFahrenheit < 45 {
                    if lowerName.contains("wool") || lowerName.contains("coat") || lowerName.contains("parka") {
                        score += 50.0
                    }
                } else if weather.temperatureFahrenheit < 65 {
                    if lowerName.contains("denim") || lowerName.contains("jacket") || lowerName.contains("cardigan") {
                        score += 40.0
                    }
                }
                if weather.isRaining {
                    if lowerName.contains("jacket") || lowerName.contains("coat") {
                        score += 30.0
                    }
                }
            case .tops:
                if weather.temperatureFahrenheit < 55 {
                    if lowerName.contains("sweater") || lowerName.contains("knit") || lowerName.contains("cashmere") || lowerName.contains("hoodie") {
                        score += 45.0
                    }
                } else if weather.temperatureFahrenheit > 75 {
                    if lowerName.contains("tee") || lowerName.contains("linen") || lowerName.contains("short") || lowerName.contains("t-shirt") {
                        score += 40.0
                    }
                } else {
                    if lowerName.contains("oxford") || lowerName.contains("shirt") || lowerName.contains("polo") {
                        score += 30.0
                    }
                }
            case .bottoms:
                if weather.temperatureFahrenheit > 78 {
                    if lowerName.contains("short") || lowerName.contains("linen") {
                        score += 40.0
                    }
                } else if weather.temperatureFahrenheit < 60 {
                    if lowerName.contains("short") {
                        score -= 60.0
                    } else if lowerName.contains("chino") || lowerName.contains("denim") || lowerName.contains("pant") || lowerName.contains("trouser") {
                        score += 30.0
                    }
                }
            case .footwear:
                if weather.isRaining || weather.temperatureFahrenheit < 50 {
                    if lowerName.contains("boot") || lowerName.contains("chelsea") || lowerName.contains("leather") {
                        score += 50.0
                    }
                } else if weather.temperatureFahrenheit > 75 {
                    if lowerName.contains("sneaker") || lowerName.contains("loafer") || lowerName.contains("sandal") {
                        score += 35.0
                    }
                }
            case .accessories:
                if weather.temperatureFahrenheit < 48 {
                    if lowerName.contains("beanie") || lowerName.contains("scarf") {
                        score += 50.0
                    }
                } else if weather.temperatureFahrenheit > 72 {
                    if lowerName.contains("sunglasses") || lowerName.contains("tote") || lowerName.contains("hat") {
                        score += 35.0
                    }
                }
            }

            // Shuffle modifier for variety
            if shuffleSeed > 0 {
                let salt = Double(abs((item.id.hashValue + shuffleSeed) % 25))
                score += salt
            }

            return (item, score)
        }

        return scored.max(by: { $0.score < $1.score })?.item
    }

    private func determineTitleAndOccasion(
        weather: DailyWeatherReport,
        picked: [WardrobeItem]
    ) -> (title: String, occasion: String) {
        if weather.isRaining {
            return ("Rain-Ready Commuter", "Weather Proof")
        }
        if weather.temperatureFahrenheit < 45 {
            return ("Winter Layered Luxe", "Cold Weather")
        } else if weather.temperatureFahrenheit < 62 {
            return ("Smart Transitional Layer", "Everyday")
        } else if weather.temperatureFahrenheit < 75 {
            return ("Effortless Smart Casual", "Office / Casual")
        } else {
            return ("Sunlit Breathable Edit", "Warm Weather")
        }
    }

    // MARK: - Smart Stylist Copy

    private func generateFallbackStylistAdvice(
        weather: DailyWeatherReport,
        picked: [WardrobeItem],
        hero: WardrobeItem?,
        heroDrop: String
    ) -> String {
        let tempText = "\(Int(weather.temperatureFahrenheit))°F"
        if let hero = hero {
            return "With today's \(weather.conditionDescription.lowercased()) conditions at \(tempText), your \(hero.name) is today's highest-yield wear. Wearing it today drops its Cost-Per-Wear by \(heroDrop), moving it closer to high utility while keeping you perfectly styled."
        } else {
            return "Tailored for \(tempText) and \(weather.conditionDescription.lowercased()) skies. This combination maximizes comfort and drops the collective Cost-Per-Wear across your wardrobe."
        }
    }

    private func enrichAdviceWithFoundationModels(
        rec: StylistRecommendation,
        weather: DailyWeatherReport,
        hero: WardrobeItem?,
        heroDrop: String
    ) async {
        guard SystemLanguageModel.default.isAvailable else { return }

        isGeneratingAdvice = true
        defer { isGeneratingAdvice = false }

        let itemNames = rec.suggestedItems.map(\.name).joined(separator: ", ")
        let heroName = hero?.name ?? "hero garment"

        let instructions = """
        You are a concise, sophisticated personal stylist and Cost-Per-Wear financial advisor.
        Provide exactly 2 sentences explaining why today's outfit is both weather-appropriate and financially optimal.
        Highlight how wearing the \(heroName) reduces its Cost-Per-Wear by \(heroDrop).
        Keep the tone encouraging, chic, and elevated.
        """

        let prompt = """
        Weather: \(weather.conditionDescription), \(Int(weather.temperatureFahrenheit))°F.
        Outfit Pieces: \(itemNames).
        Key High-CPW Hero Piece: \(heroName) (saves \(heroDrop) on CPW today).
        Write 2 sentences of personal styling advice.
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count > 20 {
                var updated = rec
                updated.stylistAdvice = trimmed
                self.currentRecommendation = updated
            }
        } catch {
            print("FoundationModels styling enrichment error: \(error.localizedDescription)")
        }
    }

    // MARK: - One-Tap Log All Items

    func logCurrentOutfit(
        in context: ModelContext,
        date: Date = Date()
    ) -> Int {
        guard let rec = currentRecommendation, !rec.suggestedItems.isEmpty else { return 0 }

        for item in rec.suggestedItems {
            let log = WearLog(loggedAt: date, item: item)
            context.insert(log)
        }

        try? context.save()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        return rec.suggestedItems.count
    }

    // MARK: - Save Recommendation to Lookbook

    func saveRecommendationToLookbook(
        name: String? = nil,
        in context: ModelContext
    ) -> SavedOutfit? {
        guard let rec = currentRecommendation, !rec.suggestedItems.isEmpty else { return nil }

        let outfitName = name ?? rec.outfitTitle
        let outfit = SavedOutfit(
            name: outfitName,
            occasion: rec.occasionTag,
            createdAt: Date(),
            lastWorn: nil,
            notes: "Curated by AI Stylist for \(rec.weather.conditionDescription) (\(Int(rec.weather.temperatureFahrenheit))°F).",
            items: rec.suggestedItems
        )

        context.insert(outfit)
        try? context.save()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        return outfit
    }
}
