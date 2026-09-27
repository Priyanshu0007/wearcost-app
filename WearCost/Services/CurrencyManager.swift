import Foundation
import SwiftUI
import Combine

/// Represents a currency option with metadata and localized display values.
public struct AppCurrency: Identifiable, Hashable {
    public let code: String
    public let name: String
    public let symbol: String
    public let flag: String?

    public var id: String { code }

    public var displayTitle: String {
        "\(name) (\(code))"
    }
}

/// Global manager responsible for currency selection, persistence, and formatting.
@MainActor
public final class CurrencyManager: ObservableObject {
    public static let shared = CurrencyManager()

    private let storageKey = "wearcost_selected_currency_code"

    /// The currently selected 3-letter ISO currency code (e.g., "USD", "EUR", "GBP").
    @Published public var selectedCurrencyCode: String {
        didSet {
            UserDefaults.standard.set(selectedCurrencyCode, forKey: storageKey)
            updateCachedFormatter()
            ThresholdManager.shared.currencyChanged(to: selectedCurrencyCode)
        }
    }

    /// All available ISO currencies found on device, sorted alphabetically by localized name.
    public let allCurrencies: [AppCurrency]

    /// Commonly used global currencies pinned for quick access.
    public let popularCurrencies: [AppCurrency]

    /// Cached NumberFormatter for performance.
    private var cachedFormatter: NumberFormatter
    private var cachedCompactFormatter: NumberFormatter

    private init() {
        // Build the comprehensive list of currencies
        let locale = Locale.current
        var uniqueCodes = Set<String>()

        // 1. Gather common ISO currency codes
        for code in Locale.commonISOCurrencyCodes {
            uniqueCodes.insert(code)
        }

        // 2. Gather full ISO currencies available in modern Foundation
        if #available(iOS 16.0, *) {
            for cur in Locale.Currency.isoCurrencies {
                uniqueCodes.insert(cur.identifier)
            }
        }

        // Map to AppCurrency structs
        let mapped = uniqueCodes.compactMap { code -> AppCurrency? in
            guard let name = locale.localizedString(forCurrencyCode: code), !name.isEmpty else {
                return nil
            }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code
            let symbol = formatter.currencySymbol ?? code
            let flagEmoji = Self.flagEmoji(for: code)
            return AppCurrency(code: code, name: name, symbol: symbol, flag: flagEmoji)
        }

        // Sort alphabetically by localized name
        let sortedCurrencies = mapped.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        self.allCurrencies = sortedCurrencies

        // Pinned popular currencies
        let popularCodes = [
            "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "INR", "CNY", "CHF",
            "BRL", "KRW", "SGD", "NZD", "MXN", "AED", "SAR", "ZAR", "SEK",
            "NOK", "DKK", "HKD", "TWD", "PLN", "THB", "IDR", "TRY"
        ]
        var popularList: [AppCurrency] = []
        for code in popularCodes {
            if let cur = sortedCurrencies.first(where: { $0.code == code }) {
                popularList.append(cur)
            }
        }
        self.popularCurrencies = popularList

        // Load saved currency code or determine best system default
        let initialCode: String
        let savedCode = UserDefaults.standard.string(forKey: storageKey)
        if let saved = savedCode, !saved.isEmpty, uniqueCodes.contains(saved) {
            initialCode = saved
        } else if let systemCurrency = locale.currency?.identifier, uniqueCodes.contains(systemCurrency) {
            initialCode = systemCurrency
        } else {
            initialCode = "USD"
        }
        self.selectedCurrencyCode = initialCode

        // Initialize formatters
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = initialCode
        self.cachedFormatter = formatter

        let compactFormatter = NumberFormatter()
        compactFormatter.numberStyle = .currency
        compactFormatter.currencyCode = initialCode
        compactFormatter.maximumFractionDigits = 0
        compactFormatter.minimumFractionDigits = 0
        self.cachedCompactFormatter = compactFormatter
    }

    private func updateCachedFormatter() {
        cachedFormatter.currencyCode = selectedCurrencyCode
        cachedCompactFormatter.currencyCode = selectedCurrencyCode
    }

    /// The AppCurrency representation of the active selection.
    public var currentCurrency: AppCurrency {
        if let match = allCurrencies.first(where: { $0.code == selectedCurrencyCode }) {
            return match
        }
        let sym = cachedFormatter.currencySymbol ?? selectedCurrencyCode
        return AppCurrency(code: selectedCurrencyCode, name: selectedCurrencyCode, symbol: sym, flag: Self.flagEmoji(for: selectedCurrencyCode))
    }

    /// The currency symbol for the active currency (e.g., "$", "€", "£", "₹").
    public var symbol: String {
        cachedFormatter.currencySymbol ?? selectedCurrencyCode
    }

    /// Formats a monetary value using the active currency and standard fraction digits.
    public func format(_ amount: Double, includeDecimals: Bool = true) -> String {
        if includeDecimals {
            return cachedFormatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(String(format: "%.2f", amount))"
        } else {
            return cachedCompactFormatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(Int(amount))"
        }
    }

    /// Formats a monetary value without fraction digits (compact representation).
    public func formatCompact(_ amount: Double) -> String {
        cachedCompactFormatter.string(from: NSNumber(value: amount)) ?? "\(symbol)\(Int(amount))"
    }

    /// Formats a Cost-Per-Wear value with decimals.
    public func formatCPW(_ amount: Double) -> String {
        format(amount, includeDecimals: true)
    }

    /// Resolves country/region flag emoji for standard ISO currency codes.
    private static func flagEmoji(for currencyCode: String) -> String? {
        let specialFlags: [String: String] = [
            "EUR": "🇪🇺",
            "USD": "🇺🇸",
            "GBP": "🇬🇧",
            "JPY": "🇯🇵",
            "CAD": "🇨🇦",
            "AUD": "🇦🇺",
            "INR": "🇮🇳",
            "CNY": "🇨🇳",
            "CHF": "🇨🇭",
            "BRL": "🇧🇷",
            "RUB": "🇷🇺",
            "KRW": "🇰🇷",
            "SGD": "🇸🇬",
            "NZD": "🇳🇿",
            "MXN": "🇲🇽",
            "HKD": "🇭🇰",
            "TRY": "🇹🇷",
            "ZAR": "🇿🇦",
            "SEK": "🇸🇪",
            "NOK": "🇳🇴",
            "DKK": "🇩🇰",
            "PLN": "🇵🇱",
            "THB": "🇹🇭",
            "IDR": "🇮🇩",
            "MYR": "🇲🇾",
            "PHP": "🇵🇭",
            "AED": "🇦🇪",
            "SAR": "🇸🇦",
            "ILS": "🇮🇱",
            "CLP": "🇨🇱",
            "COP": "🇨🇴",
            "EGP": "🇪🇬",
            "VND": "🇻🇳",
            "CZK": "🇨🇿",
            "HUF": "🇭🇺",
            "RON": "🇷🇴",
            "BGN": "🇧🇬",
            "NGN": "🇳🇬",
            "PKR": "🇵🇰",
            "BDT": "🇧🇩",
            "UAH": "🇺🇦",
            "KZT": "🇰🇿",
            "QAR": "🇶🇦",
            "KWD": "🇰🇼",
            "BHD": "🇧🇭",
            "OMR": "🇴🇲",
            "JOD": "🇯🇴",
            "LBP": "🇱🇧",
            "DZD": "🇩🇿",
            "MAD": "🇲🇦",
            "TND": "🇹🇳",
            "KES": "🇰🇪",
            "GHS": "🇬🇭",
            "ARS": "🇦🇷",
            "PEN": "🇵🇪",
            "UYU": "🇺🇾",
            "CRC": "🇨🇷",
            "DOP": "🇩🇴",
            "GTQ": "🇬🇹",
            "ISK": "🇮🇸",
            "TWD": "🇹🇼",
            "XOF": "🌍",
            "XAF": "🌍",
            "XCD": "🌴"
        ]

        if let special = specialFlags[currencyCode] {
            return special
        }

        // General fallback: first 2 characters of currency code converted to regional indicators
        guard currencyCode.count == 3 else { return nil }
        let countryPrefix = String(currencyCode.prefix(2)).uppercased()
        let base: UInt32 = 127397
        var flagStr = ""
        for scalar in countryPrefix.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90 else { return nil }
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                flagStr.unicodeScalars.append(flagScalar)
            }
        }
        return flagStr.isEmpty ? nil : flagStr
    }
}
