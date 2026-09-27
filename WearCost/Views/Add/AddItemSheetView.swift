import SwiftUI
import PhotosUI
import SwiftData

struct AddItemSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared

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
                        Text(currencyManager.symbol)
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
                                Text(currencyManager.format(price))
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(thresholdManager.tier(for: price).color)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("After 10 wears")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(currencyManager.format(price / 10.0))
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

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    rawImageData == nil ? "Choose Photo" : "Change Photo",
                    systemImage: "photo.badge.plus"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if segmentationFailed && rawImageData != nil {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    Text("Background removal unavailable for this image. Original photo will be saved.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            } else if segmentedCutoutData != nil {
                Toggle("Use original photo instead of cutout", isOn: $showOriginalInstead)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
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
