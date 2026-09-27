import Foundation
import SwiftUI
import Combine

/// Manages configurable Cost-Per-Wear formula thresholds for High, Moderate, and Low utility tiers.
@MainActor
public final class ThresholdManager: ObservableObject {
    public static let shared = ThresholdManager()

    private let highKey = "wearcost_high_cpw_threshold"
    private let moderateKey = "wearcost_moderate_cpw_threshold"
    private let customFlagKey = "wearcost_custom_thresholds_set"

    /// The maximum CPW for High Utility (items below this value are High Utility).
    @Published public var highThreshold: Double {
        didSet {
            UserDefaults.standard.set(highThreshold, forKey: highKey)
        }
    }

    /// The maximum CPW for Moderate Utility (items between high and moderate are Moderate Utility; above is Low).
    @Published public var moderateThreshold: Double {
        didSet {
            UserDefaults.standard.set(moderateThreshold, forKey: moderateKey)
        }
    }

    /// Whether the user has manually set custom thresholds.
    @Published public var hasUserCustomized: Bool {
        didSet {
            UserDefaults.standard.set(hasUserCustomized, forKey: customFlagKey)
        }
    }

    private init() {
        let isCustom = UserDefaults.standard.bool(forKey: customFlagKey)
        self.hasUserCustomized = isCustom

        let savedHigh = UserDefaults.standard.double(forKey: highKey)
        let savedModerate = UserDefaults.standard.double(forKey: moderateKey)

        if isCustom && savedHigh > 0 && savedModerate > savedHigh {
            self.highThreshold = savedHigh
            self.moderateThreshold = savedModerate
        } else {
            let defaults = Self.recommendedDefaults(for: CurrencyManager.shared.selectedCurrencyCode)
            self.highThreshold = defaults.high
            self.moderateThreshold = defaults.moderate
        }
    }

    /// Returns the utility tier for a given Cost-Per-Wear amount.
    public func tier(for cpw: Double) -> CPWUtilityTier {
        if cpw < highThreshold {
            return .high
        } else if cpw <= moderateThreshold {
            return .moderate
        } else {
            return .low
        }
    }

    /// Formatted threshold label for a utility tier.
    public func thresholdDescription(for tier: CPWUtilityTier, currency: CurrencyManager = .shared) -> String {
        switch tier {
        case .high:
            return "< \(currency.format(highThreshold)) / wear"
        case .moderate:
            return "\(currency.format(highThreshold)) – \(currency.format(moderateThreshold)) / wear"
        case .low:
            return "> \(currency.format(moderateThreshold)) / wear"
        }
    }

    /// Updates thresholds and marks them as user-customized.
    public func setCustomThresholds(high: Double, moderate: Double) {
        guard high > 0, moderate > high else { return }
        self.hasUserCustomized = true
        self.highThreshold = high
        self.moderateThreshold = moderate
    }

    /// Re-applies currency-recommended defaults if the user has not manually customized.
    public func currencyChanged(to currencyCode: String) {
        if !hasUserCustomized {
            applyRecommendedDefaults(for: currencyCode)
        }
    }

    /// Explicitly applies the recommended defaults for a currency.
    public func applyRecommendedDefaults(for currencyCode: String) {
        let defaults = Self.recommendedDefaults(for: currencyCode)
        self.highThreshold = defaults.high
        self.moderateThreshold = defaults.moderate
    }

    /// Resets back to factory defaults for the current currency and clears custom flag.
    public func resetToDefaults(for currencyCode: String) {
        self.hasUserCustomized = false
        applyRecommendedDefaults(for: currencyCode)
    }

    /// Returns sensible utility thresholds tailored to different currency magnitudes.
    public static func recommendedDefaults(for currencyCode: String) -> (high: Double, moderate: Double) {
        switch currencyCode {
        case "INR", "PKR", "BDT", "LKR", "NPR":
            return (100.0, 500.0)
        case "JPY":
            return (300.0, 1500.0)
        case "KRW":
            return (3000.0, 15000.0)
        case "IDR", "VND":
            return (30000.0, 150000.0)
        case "HUF", "CLP", "PYG", "COP":
            return (1000.0, 5000.0)
        case "THB", "TWD", "PHP", "CZK", "RUB":
            return (50.0, 250.0)
        case "SEK", "NOK", "DKK", "ZAR", "MXN", "BRL", "PLN", "TRY":
            return (20.0, 100.0)
        default:
            return (2.0, 10.0)
        }
    }
}
