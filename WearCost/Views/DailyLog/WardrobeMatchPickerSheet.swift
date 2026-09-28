import SwiftUI

struct WardrobeMatchPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    let garment: IdentifiedGarment
    let wardrobeItems: [WardrobeItem]
    let currentlyMatchedItemID: UUID?
    /// Mapping of wardrobe item ID to detected garment name (for items already matched to other pieces in the scan)
    let otherMatchedItems: [UUID: String]
    let onSelect: (UUID?) -> Void

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil

    private var filteredItems: [WardrobeItem] {
        var items = wardrobeItems

        // Filter by category if selected
        if let category = selectedCategory {
            items = items.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
        }

        // Filter by search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.category.localizedCaseInsensitiveContains(query)
            }
        } else if selectedCategory == nil {
            // Intelligent ordering: items in the same detected category first, then alphabetically
            items.sort { a, b in
                let aMatches = a.category.caseInsensitiveCompare(garment.category.rawValue) == .orderedSame
                let bMatches = b.category.caseInsensitiveCompare(garment.category.rawValue) == .orderedSame
                if aMatches != bMatches {
                    return aMatches && !bMatches
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Detected Piece Header Banner
                detectedPieceHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // Search Bar
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Category Filter Pills
                categoryFilterRow
                    .padding(.bottom, 8)

                Divider()

                // Items List
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // "Create as New Item" Option Card
                        createNewItemCard
                            .padding(.top, 12)

                        // Section Header
                        HStack {
                            Text("Wardrobe Items")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            Text("\(filteredItems.count) available")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 8)

                        // Empty State if no items found
                        if filteredItems.isEmpty {
                            emptySearchResultView
                        } else {
                            ForEach(filteredItems) { item in
                                let isSelected = item.id == currentlyMatchedItemID
                                let otherName = otherMatchedItems[item.id]

                                Button {
                                    selectMatch(item.id)
                                } label: {
                                    WardrobePickerRow(
                                        item: item,
                                        isSelected: isSelected,
                                        otherPieceName: otherName
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Match Wardrobe Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Detected Piece Header

    private var detectedPieceHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(garment.category.color.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: garment.category.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(garment.category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DETECTED PIECE")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.secondary)

                Text(garment.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(garment.category.rawValue)
                    .font(.caption2.weight(.semibold))
                if !garment.color.isEmpty {
                    Text("• \(garment.color)")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.subheadline)

            TextField("Search by item name or category...", text: $searchText)
                .font(.subheadline)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Filter Row

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedCategory = nil
                } label: {
                    Text("All (\(wardrobeItems.count))")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategory == nil ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(selectedCategory == nil ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(GarmentCategory.allCases) { cat in
                    let count = wardrobeItems.filter { $0.category.caseInsensitiveCompare(cat.rawValue) == .orderedSame }.count
                    let isSelected = selectedCategory?.caseInsensitiveCompare(cat.rawValue) == .orderedSame

                    Button {
                        if isSelected {
                            selectedCategory = nil
                        } else {
                            selectedCategory = cat.rawValue
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 11))
                            Text("\(cat.rawValue) (\(count))")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? cat.color : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Create as New Item Card

    private var createNewItemCard: some View {
        Button {
            selectMatch(nil)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 54, height: 54)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create as New Garment")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Don't link — auto-create this piece in your wardrobe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if currentlyMatchedItemID == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(currentlyMatchedItemID == nil ? Color.blue.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(currentlyMatchedItemID == nil ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty Search State

    private var emptySearchResultView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No matching items found")
                .font(.headline)

            Text("Try searching for a different keyword or selecting 'All' categories.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if !searchText.isEmpty || selectedCategory != nil {
                Button {
                    searchText = ""
                    selectedCategory = nil
                } label: {
                    Text("Reset Filters")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Selection

    private func selectMatch(_ itemID: UUID?) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onSelect(itemID)
        dismiss()
    }
}

// MARK: - Wardrobe Picker Row

struct WardrobePickerRow: View {
    let item: WardrobeItem
    let isSelected: Bool
    let otherPieceName: String?
    @ObservedObject private var currencyManager = CurrencyManager.shared

    var body: some View {
        HStack(spacing: 14) {
            // Article Photo with Category Fallback
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 54, height: 54)

                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: item.garmentCategory.iconName)
                        .font(.system(size: 24))
                        .foregroundStyle(item.garmentCategory.color)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.green : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )

            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let other = otherPieceName {
                        Text("Used for \(other)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    // Category Badge
                    HStack(spacing: 3) {
                        Image(systemName: item.garmentCategory.iconName)
                            .font(.system(size: 9))
                        Text(item.category)
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.garmentCategory.color.opacity(0.12))
                    .foregroundStyle(item.garmentCategory.color)
                    .clipShape(Capsule())

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // CPW
                    Text("\(currencyManager.format(item.costPerWear))/wear")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(item.utilityTier.color)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(item.totalWears)w")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.green.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.35) : Color.clear, lineWidth: 1.5)
        )
    }
}
