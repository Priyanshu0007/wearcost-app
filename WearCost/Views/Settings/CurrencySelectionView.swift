import SwiftUI

/// Dedicated screen for browsing, searching, and selecting from all possible world currencies.
struct CurrencySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    
    @State private var searchText = ""
    
    var body: some View {
        List {
            if searchText.isEmpty {
                // Currently selected currency
                Section("Current Currency") {
                    currencyRow(for: currencyManager.currentCurrency, isSelected: true)
                }
                
                // Popular currencies pinned for quick access
                Section("Popular Currencies") {
                    ForEach(currencyManager.popularCurrencies) { currency in
                        currencyRow(for: currency, isSelected: currency.code == currencyManager.selectedCurrencyCode)
                    }
                }
                
                // Full ISO currency roster
                Section("All Currencies (\(currencyManager.allCurrencies.count))") {
                    ForEach(currencyManager.allCurrencies) { currency in
                        currencyRow(for: currency, isSelected: currency.code == currencyManager.selectedCurrencyCode)
                    }
                }
            } else {
                // Filtered search results
                Section("Search Results (\(filteredCurrencies.count))") {
                    if filteredCurrencies.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No currencies match \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredCurrencies) { currency in
                            currencyRow(for: currency, isSelected: currency.code == currencyManager.selectedCurrencyCode)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search by name, code (USD), or symbol ($)")
    }
    
    private var filteredCurrencies: [AppCurrency] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return currencyManager.allCurrencies }
        
        return currencyManager.allCurrencies.filter { currency in
            currency.code.lowercased().contains(query) ||
            currency.name.lowercased().contains(query) ||
            currency.symbol.lowercased().contains(query)
        }
    }
    
    private func currencyRow(for currency: AppCurrency, isSelected: Bool) -> some View {
        Button {
            selectCurrency(currency)
        } label: {
            HStack(spacing: 12) {
                // Flag or symbol icon
                if let flag = currency.flag {
                    Text(flag)
                        .font(.system(size: 26))
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(width: 32, height: 32)
                        Text(currency.symbol)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Name and code
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(currency.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Symbol badge
                Text(currency.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func selectCurrency(_ currency: AppCurrency) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        withAnimation(.easeInOut) {
            currencyManager.selectedCurrencyCode = currency.code
        }
    }
}
