import SwiftUI
import SwiftData

struct LookbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedOutfit.createdAt, order: .reverse) private var outfits: [SavedOutfit]
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedOccasionFilter: String? = nil
    @State private var showingCreateSheet = false

    private let occasions = ["Casual", "Work", "Formal", "Weekend", "Cold Weather", "Travel"]

    var body: some View {
        VStack(spacing: 16) {
            // Header stats & occasion pills
            if !outfits.isEmpty {
                lookbookOverviewCard
                occasionFilterRow
            }

            // Outfits list or empty state
            if filteredOutfits.isEmpty {
                emptyLookbookView
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(filteredOutfits) { outfit in
                        OutfitCardView(outfit: outfit)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateOutfitSheetView()
        }
    }

    // MARK: - Overview Card
    private var lookbookOverviewCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LOOKBOOK COMBOS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text("\(outfits.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("PORTFOLIO VALUE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                let totalCost = outfits.reduce(0.0) { $0 + $1.totalCost }
                Text(currencyManager.formatCompact(totalCost))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 28)

            Button {
                showingCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New Combo")
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Filter Row
    private var occasionFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedOccasionFilter = nil
                } label: {
                    Text("All (\(outfits.count))")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedOccasionFilter == nil ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(selectedOccasionFilter == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(occasions, id: \.self) { occ in
                    let isSelected = selectedOccasionFilter == occ
                    let count = outfits.filter { $0.occasion == occ }.count
                    if count > 0 || isSelected {
                        Button {
                            selectedOccasionFilter = occ
                        } label: {
                            Text("\(occ) (\(count))")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State
    private var emptyLookbookView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.top, 24)

            VStack(spacing: 6) {
                Text(outfits.isEmpty ? "No Saved Lookbook Combos" : "No Matching Combos")
                    .font(.headline)

                Text(outfits.isEmpty
                     ? "Create custom outfits like 'Office Formal' or 'Weekend Casual' to log all pieces together in one tap."
                     : "Try changing your occasion filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if outfits.isEmpty {
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Create First Combo", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var filteredOutfits: [SavedOutfit] {
        if let occ = selectedOccasionFilter {
            return outfits.filter { $0.occasion == occ }
        }
        return outfits
    }
}
