import SwiftUI
import PhotosUI
import SwiftData

struct AddItemSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var category: GarmentCategory = .tops
    @State private var purchasePriceText: String = ""
    @State private var purchaseDate: Date = Date()

    // PhotosPicker state
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var rawImageData: Data? = nil
    @State private var segmentedCutoutData: Data? = nil
    @State private var isSegmenting = false
    @State private var segmentationStatusMessage: String = ""
    @State private var showOriginalInstead = false
    @State private var segmentationFailed = false

    private let segmenter = ImageSegmenter()

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Photo selection & Vision cutout synthesis
                Section {
                    photoPickerAndPreviewSection
                } header: {
                    Text("Garment Photo")
                } footer: {
                    Text("Apple Neural Engine isolates the garment cutout instantly and automatically removes backgrounds on-device.")
                }

                // Section 2: Garment metadata
                Section("Garment Details") {
                    TextField("Name (e.g., Raw Denim Jacket)", text: $name)
                        .autocorrectionDisabled()

                    Picker("Category", selection: $category) {
                        ForEach(GarmentCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                }

                // Section 3: Purchase information
                Section("Investment Details") {
                    HStack {
                        Text("Purchase Price")
                        Spacer()
                        Text(Locale.current.currencySymbol ?? "$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $purchasePriceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    DatePicker("Date Purchased", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                }

                // Section 4: Initial CPW preview
                if let price = parsedPrice, price > 0 {
                    Section("Starting Cost Per Wear") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cost Per Wear at 0 wears")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "$%.2f", price))
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(price < 2.0 ? .green : (price <= 10.0 ? .orange : .red))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("After 10 wears")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "$%.2f", price / 10.0))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("New Garment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Wardrobe") {
                        saveItem()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await processSelectedPhoto(newItem)
                }
            }
        }
    }

    // MARK: - Photo Preview & Neural Engine Picker
    private var photoPickerAndPreviewSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 220)

                if isSegmenting {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(segmentationStatusMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else if let displayData = currentImageDataToDisplay, let image = UIImage(data: displayData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .frame(maxHeight: 200)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Text("Select a photo of your garment")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)

            HStack {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(rawImageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                if rawImageData != nil && segmentedCutoutData != nil {
                    Button {
                        showOriginalInstead.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showOriginalInstead ? "sparkles" : "photo")
                            Text(showOriginalInstead ? "Show Cutout" : "Show Original")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
            .padding(.horizontal, 4)

            if segmentationFailed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Could not isolate subject cleanly. Original photo will be used.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }

    private var currentImageDataToDisplay: Data? {
        if showOriginalInstead {
            return rawImageData
        }
        return segmentedCutoutData ?? rawImageData
    }

    private var parsedPrice: Double? {
        Double(purchasePriceText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (parsedPrice != nil && (parsedPrice ?? 0) >= 0) &&
        !isSegmenting
    }

    // MARK: - Vision Processing Pipeline
    private func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        await MainActor.run {
            isSegmenting = true
            segmentationStatusMessage = "Reading image data..."
            segmentationFailed = false
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    isSegmenting = false
                    segmentationStatusMessage = ""
                }
                return
            }

            await MainActor.run {
                self.rawImageData = data
                self.segmentationStatusMessage = "Neural Engine isolating garment..."
            }

            let result = await segmenter.extractForegroundWithFallback(from: data)

            await MainActor.run {
                self.segmentedCutoutData = result.data
                self.segmentationFailed = !result.wasSegmented
                self.isSegmenting = false
                self.segmentationStatusMessage = ""

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(result.wasSegmented ? .success : .warning)
            }
        } catch {
            await MainActor.run {
                self.isSegmenting = false
                self.segmentationFailed = true
                self.segmentationStatusMessage = ""
            }
        }
    }

    private func saveItem() {
        guard let price = parsedPrice else { return }

        let finalImageData = showOriginalInstead ? rawImageData : (segmentedCutoutData ?? rawImageData)

        let newItem = WardrobeItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.rawValue,
            purchasePrice: price,
            datePurchased: purchaseDate,
            imageData: finalImageData
        )

        modelContext.insert(newItem)
        try? modelContext.save()

        dismiss()
    }
}
