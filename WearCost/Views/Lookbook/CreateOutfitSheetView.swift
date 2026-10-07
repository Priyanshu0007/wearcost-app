import SwiftUI
import SwiftData

struct CreateOutfitSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @Query(sort: \WardrobeItem.name) private var allItems: [WardrobeItem]

    @State private var outfitName: String = ""
    @State private var occasion: String = "Casual"
    @State private var notes: String = ""
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var selectedCategoryFilter: String? = nil

    private let occasions = ["Casual", "Work", "Formal", "Weekend", "Evening", "Travel", "Cold Weather"]

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Outfit Details Card
                    detailsSection

                    // Live Cost & CPW Summary
                    if !selectedItems.isEmpty {
                        outfitMetricsSection
                    }

                    // Category Filter Pills
                    categoryFilterRow

                    // Garment Selector Grid
                    garmentsSelectionGrid
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Create Outfit Combo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveOutfit()
                    }
                    .disabled(outfitName.trimmingCharacters(in: .whitespaces).isEmpty || selectedItemIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Outfit Name (e.g. Office Formal, Weekend Denim)", text: $outfitName)
                .font(.headline)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quick Occasion Tags
            VStack(alignment: .leading, spacing: 6) {
                Text("OCCASION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(occasions, id: \.self) { occ in
                            Button {
                                occasion = occ
                            } label: {
                                Text(occ)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(occasion == occ ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                                    .foregroundStyle(occasion == occ ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            TextField("Notes (optional)", text: $notes)
                .font(.subheadline)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Metrics Summary
    private var outfitMetricsSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL VALUE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                let totalCost = selectedItems.reduce(0.0) { $0 + $1.purchasePrice }
                Text(currencyManager.format(totalCost))
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("AVG CPW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                let avgCPW = selectedItems.isEmpty ? 0.0 : (selectedItems.reduce(0.0) { $0 + $1.costPerWear } / Double(selectedItems.count))
                Text(currencyManager.format(avgCPW))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ThresholdManager.shared.tier(for: avgCPW).color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("PIECES")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(selectedItems.count)")
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - Category Filter Row
    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategoryFilter = nil
                } label: {
                    Text("All (\(allItems.count))")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategoryFilter == nil ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(selectedCategoryFilter == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(GarmentCategory.allCases) { cat in
                    let isSelected = selectedCategoryFilter == cat.rawValue
                    let count = allItems.filter { $0.category == cat.rawValue }.count
                    Button {
                        selectedCategoryFilter = cat.rawValue
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                            Text("\(cat.rawValue) (\(count))")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? cat.color : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Garments Grid
    private var garmentsSelectionGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(displayedItems) { item in
                let isSelected = selectedItemIDs.contains(item.id)
                Button {
                    toggleItem(item)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .frame(height: 95)

                            if let imageData = item.imageData, let img = UIImage(data: imageData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                                    .frame(maxWidth: .infinity, maxHeight: 95)
                            } else {
                                Image(systemName: item.garmentCategory.iconName)
                                    .font(.system(size: 28))
                                    .foregroundStyle(item.garmentCategory.color)
                                    .frame(maxWidth: .infinity, maxHeight: 95)
                            }

                            // Selection Check
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.black.opacity(0.3))
                                    .frame(width: 22, height: 22)
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(6)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            Text(currencyManager.format(item.costPerWear))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.utilityTier.color)
                        }
                        .padding(.horizontal, 2)
                    }
                    .padding(6)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var displayedItems: [WardrobeItem] {
        if let filter = selectedCategoryFilter {
            return allItems.filter { $0.category == filter }
        }
        return allItems
    }

    private var selectedItems: [WardrobeItem] {
        allItems.filter { selectedItemIDs.contains($0.id) }
    }

    private func toggleItem(_ item: WardrobeItem) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func saveOutfit() {
        let trimmedName = outfitName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !selectedItemIDs.isEmpty else { return }

        let outfit = SavedOutfit(
            name: trimmedName,
            occasion: occasion,
            createdAt: Date(),
            lastWorn: nil,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes,
            items: selectedItems
        )

        modelContext.insert(outfit)
        try? modelContext.save()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        dismiss()
    }
}
