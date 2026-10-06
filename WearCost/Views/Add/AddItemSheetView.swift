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

    // PhotosPicker & Segmentation state
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var rawImageData: Data? = nil
    @State private var segmentedCutoutData: Data? = nil
    @State private var isSegmenting = false
    @State private var segmentationStatusMessage: String = ""
    @State private var showOriginalInstead = false
    @State private var segmentationFailed = false

    // On-Device AI Scan & Suggestion state
    @State private var isAIScanning = false
    @State private var aiSuggestion: DetectedSingleGarmentResult? = nil
    @State private var aiSuggestionDismissed = false
    @State private var aiSuggestionApplied = false

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

                // Section 2: On-Device AI Scan / Suggestion Card (Appears on User Approval)
                if isAIScanning {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scanning with On-Device AI...")
                                    .font(.subheadline.weight(.semibold))
                                Text("Identifying garment type and category")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if let suggestion = aiSuggestion, !aiSuggestionDismissed {
                    Section {
                        aiSuggestionApprovalView(suggestion: suggestion)
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                            Text("Apple AI Recognition")
                        }
                    } footer: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption2)
                            Text(suggestion.source)
                                .font(.caption2)
                        }
                    }
                }

                // Section 3: Garment metadata
                Section {
                    TextField("Name (e.g., Raw Denim Jacket)", text: $name)
                        .autocorrectionDisabled()

                    Picker("Category", selection: $category) {
                        ForEach(GarmentCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName)
                                .tag(cat)
                        }
                    }
                } header: {
                    HStack {
                        Text("Garment Details")
                        if aiSuggestionApplied {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Populated via AI")
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.purple)
                        }
                    }
                }

                // Section 4: Purchase information
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

                // Section 5: Initial CPW preview
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
                    Button("Add") {
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

            HStack(spacing: 10) {
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

                if let data = rawImageData, let img = UIImage(data: data), !isAIScanning {
                    Button {
                        Task {
                            await analyzeGarmentWithAI(image: img)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Scan AI")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - AI Suggestion & Approval View
    private func aiSuggestionApprovalView(suggestion: DetectedSingleGarmentResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(suggestion.category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: suggestion.category.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(suggestion.category.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(suggestion.category.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(suggestion.category.color)

                        if !suggestion.color.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(suggestion.color)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if aiSuggestionApplied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Applied")
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }
            }

            if !aiSuggestionApplied {
                HStack(spacing: 10) {
                    Button {
                        applyAISuggestion(suggestion)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Use Suggestion")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation {
                            aiSuggestionDismissed = true
                        }
                    } label: {
                        Text("Dismiss")
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func applyAISuggestion(_ suggestion: DetectedSingleGarmentResult) {
        withAnimation(.easeInOut(duration: 0.25)) {
            name = suggestion.name
            category = suggestion.category
            aiSuggestionApplied = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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

    // MARK: - Vision & AI Processing Pipeline
    private func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        await MainActor.run {
            isSegmenting = true
            segmentationStatusMessage = "Reading image data..."
            segmentationFailed = false
            aiSuggestion = nil
            aiSuggestionDismissed = false
            aiSuggestionApplied = false
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    isSegmenting = false
                    segmentationStatusMessage = ""
                }
                return
            }

            guard let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    isSegmenting = false
                    segmentationStatusMessage = ""
                }
                return
            }

            await MainActor.run {
                self.rawImageData = data
                self.segmentationStatusMessage = "Neural Engine isolating garment..."
                self.isAIScanning = true
            }

            // Run foreground segmentation and AI garment analysis concurrently
            async let segmentationTask = segmenter.extractForegroundWithFallback(from: data)
            async let aiScanTask = OutfitAnalysisService.shared.analyzeSingleGarment(image: uiImage)

            let segResult = await segmentationTask

            await MainActor.run {
                self.segmentedCutoutData = segResult.data
                self.segmentationFailed = !segResult.wasSegmented
                self.isSegmenting = false
                self.segmentationStatusMessage = ""
            }

            let detectedAI = await aiScanTask

            await MainActor.run {
                self.aiSuggestion = detectedAI
                self.isAIScanning = false
                self.aiSuggestionApplied = false

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.isSegmenting = false
                self.isAIScanning = false
                self.segmentationFailed = true
                self.segmentationStatusMessage = ""
            }
        }
    }

    private func analyzeGarmentWithAI(image: UIImage) async {
        await MainActor.run {
            isAIScanning = true
            aiSuggestionDismissed = false
        }

        let result = await OutfitAnalysisService.shared.analyzeSingleGarment(image: image)

        await MainActor.run {
            self.aiSuggestion = result
            self.isAIScanning = false
            self.aiSuggestionDismissed = false
            self.aiSuggestionApplied = false

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
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
