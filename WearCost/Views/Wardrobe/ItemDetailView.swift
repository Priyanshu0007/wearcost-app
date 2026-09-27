import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared

    @Bindable var item: WardrobeItem
    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var isAnimatingWearAction = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cutout Hero Display
                imageHeroSection

                // Key CPW & Stats Grid
                statsMetricsSection

                // Target Milestones Card
                milestoneSection

                // Quick Log Wear Button
                quickLogButton

                // Wear History Section
                wearHistorySection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Item", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete \(item.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Item", role: .destructive) {
                deleteItem()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this garment and all associated wear logs.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditItemSheet(item: item)
        }
    }

    // MARK: - Hero Image Section
    private var imageHeroSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)

            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .padding(20)
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: item.garmentCategory.iconName)
                        .font(.system(size: 64))
                        .foregroundStyle(item.garmentCategory.color)
                    Text("No Cutout Available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 220)
            }
        }
        .frame(height: 280)
        .overlay(alignment: .topTrailing) {
            categoryBadge
                .padding(16)
        }
    }

    private var categoryBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: item.garmentCategory.iconName)
            Text(item.category)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(item.garmentCategory.color)
    }

    // MARK: - Stats Section
    private var statsMetricsSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Cost-per-wear Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("COST PER WEAR")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currencyManager.format(item.costPerWear))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(item.utilityTier.color)
                        Text("/ wear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: item.utilityTier.iconName)
                        Text(item.utilityTier.rawValue)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.utilityTier.color)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // Total Wears Card
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL WEARS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(item.totalWears)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(item.totalWears == 1 ? "time" : "times")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text("Original: \(currencyManager.format(item.purchasePrice))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            // Secondary metrics row
            HStack {
                Label("Purchased \(item.datePurchased.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Spacer()
                let days = max(1, Calendar.current.dateComponents([.day], from: item.datePurchased, to: Date()).day ?? 1)
                Text("\(days) days owned")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Milestones Section
    private var milestoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Color.accentColor)
                Text("Utility Milestone")
                    .font(.headline)
                Spacer()
            }

            if let milestone = item.nextMilestone {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Target: \(currencyManager.format(milestone.targetCPW)) / wear")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(milestone.wearsNeeded) more wear\(milestone.wearsNeeded == 1 ? "" : "s")")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }

                    ProgressView(value: milestone.progress)
                        .tint(Color.accentColor)

                    Text("Wear this item \(milestone.wearsNeeded) more \(milestone.wearsNeeded == 1 ? "time" : "times") to bring your cost per wear down to \(currencyManager.format(milestone.targetCPW)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Top Utility Achieved! Below \(currencyManager.format(thresholdManager.highThreshold)) per wear.")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Quick Log Button
    private var quickLogButton: some View {
        Button {
            logSingleWear()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Log Wear Today (+1)")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isAnimatingWearAction ? 0.96 : 1.0)
        }
    }

    // MARK: - Wear History Section
    private var wearHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wear History")
                    .font(.headline)
                Spacer()
                Text("\(sortedLogs.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No wears recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap 'Log Wear Today' to record your first wear.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedLogs.enumerated()), id: \.element.id) { index, log in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.loggedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.medium))
                                Text("Wear #\(sortedLogs.count - index)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button(role: .destructive) {
                                deleteLog(log)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < sortedLogs.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var sortedLogs: [WearLog] {
        (item.wearLogs ?? []).sorted(by: { $0.loggedAt > $1.loggedAt })
    }

    private func logSingleWear() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isAnimatingWearAction = true
        }

        let newLog = WearLog(loggedAt: Date(), item: item)
        modelContext.insert(newLog)
        try? modelContext.save()

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isAnimatingWearAction = false
            }
        }
    }

    private func deleteLog(_ log: WearLog) {
        withAnimation {
            modelContext.delete(log)
            try? modelContext.save()
        }
    }

    private func deleteItem() {
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Item Sheet
struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Bindable var item: WardrobeItem

    @State private var name: String = ""
    @State private var category: GarmentCategory = .tops
    @State private var purchasePrice: Double = 0.0
    @State private var datePurchased: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(GarmentCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }

                Section("Purchase Info") {
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0.00", value: $purchasePrice, format: .currency(code: currencyManager.selectedCurrencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Purchase Date", selection: $datePurchased, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Garment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.category = category.rawValue
                        item.purchasePrice = purchasePrice
                        item.datePurchased = datePurchased
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = item.name
                category = item.garmentCategory
                purchasePrice = item.purchasePrice
                datePurchased = item.datePurchased
            }
        }
    }
}
