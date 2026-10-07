import SwiftUI
import SwiftData

struct DailyLogSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @Query(sort: \WardrobeItem.name) private var items: [WardrobeItem]
    @Query(sort: \SavedOutfit.createdAt, order: .reverse) private var savedOutfits: [SavedOutfit]

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var aiDetectedItemIDs: Set<UUID> = []
    @State private var outfitSummaryText: String? = nil
    @State private var showingAIScanSheet = false
    @State private var logDate: Date = Date()
    @State private var selectedCategoryFilter: String? = nil
    @State private var showingConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Pills
                categoryFilterRow

                // Lookbook Quick Fill Row
                if !savedOutfits.isEmpty {
                    lookbookQuickFillRow
                }

                // AI Outfit Scan Banner
                if outfitSummaryText != nil {
                    aiSummaryBanner
                } else {
                    aiScanBanner
                }

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
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(displayedItems) { item in
                                OutfitItemSelectCard(
                                    item: item,
                                    isSelected: selectedItemIDs.contains(item.id),
                                    isAiDetected: aiDetectedItemIDs.contains(item.id)
                                ) {
                                    toggleSelection(for: item)
                                }
                            }
                        }
                        .padding(16)
                    }
                }

                // Bottom Action Button
                bottomActionBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Log Daily Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker("", selection: $logDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .sheet(isPresented: $showingAIScanSheet) {
                AIOutfitScanSheet(
                    wardrobeItems: items,
                    selectedItemIDs: $selectedItemIDs,
                    aiDetectedItemIDs: $aiDetectedItemIDs,
                    outfitSummaryText: $outfitSummaryText
                ) {
                    commitOutfitLog()
                }
            }
            .alert("Outfit Logged!", isPresented: $showingConfirmation) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Successfully logged \(selectedItemIDs.count) pieces for \(logDate.formatted(date: .abbreviated, time: .omitted)). Their Cost-Per-Wear has been updated!")
            }
        }
    }

    // MARK: - Lookbook Quick Fill Row
    private var lookbookQuickFillRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOAD FROM LOOKBOOK")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(savedOutfits) { outfit in
                        Button {
                            applyLookbook(outfit)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.accentColor)

                                Text(outfit.name)
                                    .font(.caption.weight(.medium))

                                Text("(\(outfit.itemsCount))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 4)
    }

    private func applyLookbook(_ outfit: SavedOutfit) {
        guard let list = outfit.items, !list.isEmpty else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        selectedItemIDs = Set(list.map(\.id))
        outfitSummaryText = "Loaded '\(outfit.name)' Lookbook combo (\(list.count) pieces)."
    }

    // MARK: - AI Scan Banners

    private var aiScanBanner: some View {
        Button {
            showingAIScanSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Scan Outfit with AI")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Vision & LLM")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }

                    Text("Snap or pick a mirror selfie to auto-select worn pieces.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .buttonStyle(.plain)
    }

    private var aiSummaryBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark.sparkles.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let summary = outfitSummaryText {
                    Text(summary)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                Text("\(aiDetectedItemIDs.count) pieces auto-selected by Apple AI")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingAIScanSheet = true
            } label: {
                Text("Rescan")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 6)
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

    // MARK: - Empty Wardrobe Prompt
    private var emptyWardrobePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No Clothes Added Yet")
                    .font(.headline)

                Text("Add items to your wardrobe first to start logging your daily outfits and tracking Cost-Per-Wear.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
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

        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)

        showingConfirmation = true
    }
}

// MARK: - Outfit Item Selection Card
struct OutfitItemSelectCard: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    let item: WardrobeItem
    let isSelected: Bool
    var isAiDetected: Bool = false
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

                    // Top-Left AI Matched Badge
                    if isAiDetected {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                            Text("AI Matched")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.purple)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    // Selection Checkmark Circle
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
                        Text(currencyManager.format(item.costPerWear))
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
                    .stroke(isSelected ? (isAiDetected ? Color.purple : Color.accentColor) : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: isSelected ? (isAiDetected ? Color.purple.opacity(0.25) : Color.accentColor.opacity(0.2)) : .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
