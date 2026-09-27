import SwiftUI
import SwiftData

struct DailyLogSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var logDate: Date = Date()
    @State private var selectedCategoryFilter: String? = nil
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Outfit Summary Banner
                if !selectedItemIDs.isEmpty {
                    selectedOutfitSummaryBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Category Filter Pills
                categoryFilterRow

                // Items Selection List / Grid
                if items.isEmpty {
                    emptyWardrobePrompt
                } else if displayedItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "slash.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No items in this category.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 190), spacing: 12)], spacing: 12) {
                            ForEach(displayedItems) { item in
                                let isSelected = selectedItemIDs.contains(item.id)
                                OutfitItemSelectCard(item: item, isSelected: isSelected) {
                                    toggleSelection(for: item)
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                // Bottom Log Action Bar
                bottomActionBar
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Log Daily Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !items.isEmpty {
                        Button(selectedItemIDs.count == items.count ? "Deselect All" : "Select All") {
                            if selectedItemIDs.count == items.count {
                                selectedItemIDs.removeAll()
                            } else {
                                selectedItemIDs = Set(items.map { $0.id })
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
        }
    }

    // MARK: - Selected Outfit Summary
    private var selectedOutfitSummaryBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    Text("\(selectedItemIDs.count) Pieces Selected")
                        .font(.subheadline.weight(.bold))
                }

                Spacer()

                DatePicker("", selection: $logDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
            }

            // Calculation preview
            let selectedItems = items.filter { selectedItemIDs.contains($0.id) }
            let totalValue = selectedItems.reduce(0.0) { $0 + $1.purchasePrice }
            let currentCPWSum = selectedItems.reduce(0.0) { $0 + $1.costPerWear }
            let newCPWSum = selectedItems.reduce(0.0) { sum, item in
                sum + (item.purchasePrice / Double(item.totalWears + 1))
            }
            let savings = max(0.0, currentCPWSum - newCPWSum)

            HStack {
                Text("Total outfit cost: \(String(format: "$%.2f", totalValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if savings > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                        Text(String(format: "CPW - $%.2f", savings))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay(Divider(), alignment: .bottom)
    }

    // MARK: - Category Filter Row
    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategoryFilter = nil
                } label: {
                    Text("All Items")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategoryFilter == nil ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(selectedCategoryFilter == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(GarmentCategory.allCases) { cat in
                    let isSelected = selectedCategoryFilter == cat.rawValue
                    Button {
                        selectedCategoryFilter = cat.rawValue
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                            Text(cat.rawValue)
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
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Divider()
            Button {
                commitOutfitLog()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text(selectedItemIDs.isEmpty ? "Select Pieces to Log" : "Log Outfit (\(selectedItemIDs.count) items)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedItemIDs.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedItemIDs.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var emptyWardrobePrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "hanger")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No garments in your wardrobe yet")
                .font(.headline)
            Text("Add garments first to log your daily outfits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayedItems: [WardrobeItem] {
        if let filter = selectedCategoryFilter {
            return items.filter { $0.category == filter }
        }
        return items
    }

    private func toggleSelection(for item: WardrobeItem) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func commitOutfitLog() {
        guard !selectedItemIDs.isEmpty else { return }

        for item in items where selectedItemIDs.contains(item.id) {
            let log = WearLog(loggedAt: logDate, item: item)
            modelContext.insert(log)
        }

        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Outfit Item Selection Card
struct OutfitItemSelectCard: View {
    let item: WardrobeItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .frame(height: 120)

                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                    } else {
                        Image(systemName: item.garmentCategory.iconName)
                            .font(.system(size: 36))
                            .foregroundStyle(item.garmentCategory.color)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                    }

                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.black.opacity(0.3))
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    HStack {
                        Text(String(format: "$%.2f", item.costPerWear))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.utilityTier.color)
                        Spacer()
                        Text("\(item.totalWears)w")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: isSelected ? Color.accentColor.opacity(0.2) : .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
