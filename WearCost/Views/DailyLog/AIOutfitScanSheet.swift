import SwiftUI
import PhotosUI
import SwiftData

struct AIOutfitScanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared

    let wardrobeItems: [WardrobeItem]
    @Binding var selectedItemIDs: Set<UUID>
    @Binding var aiDetectedItemIDs: Set<UUID>
    @Binding var outfitSummaryText: String?
    let onCommitLog: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var inputImage: UIImage?
    @State private var isAnalyzing: Bool = false
    @State private var analysisResult: IdentifiedOutfitResult? = nil
    @State private var detectedGarments: [IdentifiedGarment] = []
    @State private var errorMessage: String? = nil

    init(
        wardrobeItems: [WardrobeItem],
        selectedItemIDs: Binding<Set<UUID>>,
        aiDetectedItemIDs: Binding<Set<UUID>>,
        outfitSummaryText: Binding<String?>,
        initialImage: UIImage? = nil,
        onCommitLog: @escaping () -> Void
    ) {
        self.wardrobeItems = wardrobeItems
        self._selectedItemIDs = selectedItemIDs
        self._aiDetectedItemIDs = aiDetectedItemIDs
        self._outfitSummaryText = outfitSummaryText
        self._inputImage = State(initialValue: initialImage)
        self.onCommitLog = onCommitLog
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo & Analysis Banner
                    photoHeaderSection

                    // Live Analysis Loading State
                    if isAnalyzing {
                        analyzingStatusCard
                    }

                    // Analysis Results & Garment Verification
                    if let result = analysisResult {
                        aiSummaryCard(result)

                        detectedGarmentsSection

                        if !hasExistingWardrobeItems && !detectedGarments.isEmpty {
                            newItemsWardrobeNotice
                        }
                    }

                    // Error Message
                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .padding(.bottom, 90) // Ample padding to ensure bottom cards scroll cleanly above the floating bar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Scan Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                if analysisResult != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            applySelectionsAndDismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if analysisResult != nil {
                    bottomConfirmationBar
                }
            }
            .task {
                if let initial = inputImage, analysisResult == nil {
                    await startAnalysis(image: initial)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadAndAnalyzePhoto(newItem)
                }
            }
        }
    }

    // MARK: - Photo Header

    private var photoHeaderSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 220)

                if let image = inputImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Apple AI")
                            }
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Add Today's Outfit Photo")
                            .font(.headline)
                        Text("Apple AI will recognize your clothes and auto-populate your wear log.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: inputImage == nil ? "camera.fill" : "arrow.triangle.2.circlepath.camera")
                    Text(inputImage == nil ? "Choose Outfit Photo" : "Choose Different Photo")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Analyzing Status Card

    private var analyzingStatusCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.purple)

            VStack(spacing: 4) {
                Text("Analyzing with Apple AI...")
                    .font(.headline)

                Text("Extracting garments, colors, and matching with your wardrobe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.4), .blue.opacity(0.4), .cyan.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - AI Summary Card

    private func aiSummaryCard(_ result: IdentifiedOutfitResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("OUTFIT RECOGNITION")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(result.summary)
                .font(.headline)
                .foregroundStyle(.primary)

            let matchedCount = detectedGarments.filter { $0.matchedWardrobeItemID != nil }.count
            let totalCount = detectedGarments.count

            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("\(totalCount) pieces detected • \(matchedCount) matched to wardrobe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Detected Garments Section

    private var detectedGarmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verify Detected Pieces")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach($detectedGarments) { $garment in
                detectedGarmentRow(garment: $garment)
            }
        }
    }

    private func detectedGarmentRow(garment: Binding<IdentifiedGarment>) -> some View {
        let piece = garment.wrappedValue
        let matchedItem = wardrobeItems.first(where: { $0.id == piece.matchedWardrobeItemID })

        return VStack(alignment: .leading, spacing: 12) {
            // Top Row: Checkbox, Detected Category Icon, Detected Garment Name & Match Tag
            HStack(spacing: 12) {
                Button {
                    garment.isSelected.wrappedValue.toggle()
                } label: {
                    Image(systemName: piece.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(piece.isSelected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)

                // Category Icon
                ZStack {
                    Circle()
                        .fill(piece.category.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: piece.category.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(piece.category.color)
                }

                // Detected details
                VStack(alignment: .leading, spacing: 2) {
                    Text(piece.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Text(piece.category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if !piece.color.isEmpty {
                            Text("• \(piece.color)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if matchedItem != nil {
                    Text("Matched")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else {
                    Text("New Piece")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            // Prominent Matched Wardrobe Item Callout Box
            if let matched = matchedItem {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                        Text("MATCHED WARDROBE ITEM")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.secondary)

                        Spacer()

                        matchMenu(for: garment, matchedItem: matched)
                    }

                    HStack(spacing: 12) {
                        // Wardrobe item thumbnail / icon
                        if let data = matched.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(matched.garmentCategory.color.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                Image(systemName: matched.garmentCategory.iconName)
                                    .font(.system(size: 22))
                                    .foregroundStyle(matched.garmentCategory.color)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(matched.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 6) {
                                Text("\(currencyManager.format(matched.costPerWear))/wear")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(matched.utilityTier.color)

                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text("\(matched.totalWears) total wears")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                )
            } else {
                // New Item Callout Box
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.subheadline)
                        Text("NEW GARMENT (NOT IN WARDROBE)")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if !wardrobeItems.isEmpty {
                            matchMenu(for: garment, matchedItem: nil)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Will be automatically created in your wardrobe and logged as worn today.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(piece.isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Match Menu (Change or Assign Match)

    private func matchMenu(for garment: Binding<IdentifiedGarment>, matchedItem: WardrobeItem?) -> some View {
        Menu {
            Section("Select Wardrobe Item") {
                ForEach(wardrobeItems) { item in
                    Button {
                        garment.matchedWardrobeItemID.wrappedValue = item.id
                    } label: {
                        HStack {
                            Text(item.name)
                            if item.id == garment.matchedWardrobeItemID.wrappedValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if matchedItem != nil {
                Button(role: .destructive) {
                    garment.matchedWardrobeItemID.wrappedValue = nil
                } label: {
                    Label("Unlink (Create as New Item)", systemImage: "xmark.circle")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(matchedItem == nil ? "Match with..." : "Change Match")
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - New Items Notice

    private var newItemsWardrobeNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
                Text("Automatic Wardrobe Creation")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }
            Text("These detected garments will be automatically added to your wardrobe and marked as worn today, kicking off their Cost-Per-Wear tracking!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bottom Confirmation Bar

    private var bottomConfirmationBar: some View {
        let selectedCount = detectedGarments.filter { $0.isSelected }.count

        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    applySelectionsAndDismiss()
                } label: {
                    Text("Auto-Populate")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    applySelectionsAndCommit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save & Log (\(selectedCount))")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedCount == 0 ? Color.gray.opacity(0.3) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Processing Helpers

    private var hasExistingWardrobeItems: Bool {
        !wardrobeItems.isEmpty
    }

    private func loadAndAnalyzePhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = "Unable to read image."
                }
                return
            }

            await MainActor.run {
                self.inputImage = uiImage
            }

            await startAnalysis(image: uiImage)
        } catch {
            await MainActor.run {
                isAnalyzing = false
                errorMessage = "Failed to load photo: \(error.localizedDescription)"
            }
        }
    }

    private func startAnalysis(image: UIImage) async {
        await MainActor.run {
            isAnalyzing = true
            errorMessage = nil
        }

        let result = await OutfitAnalysisService.shared.analyzeOutfit(
            image: image,
            wardrobeItems: wardrobeItems
        )

        await MainActor.run {
            self.analysisResult = result
            self.detectedGarments = result.garments
            self.isAnalyzing = false

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    // MARK: - Actions

    private func applySelectionsAndDismiss() {
        processSelections()
        dismiss()
    }

    private func applySelectionsAndCommit() {
        processSelections()
        onCommitLog()
        dismiss()
    }

    private func processSelections() {
        var newSelectedIDs = Set<UUID>()
        var aiMatchedIDs = Set<UUID>()

        for garment in detectedGarments where garment.isSelected {
            if let matchedID = garment.matchedWardrobeItemID {
                newSelectedIDs.insert(matchedID)
                aiMatchedIDs.insert(matchedID)
            } else {
                // Newly detected garment not in wardrobe: create item in context
                let newItem = WardrobeItem(
                    name: garment.name,
                    category: garment.category.rawValue,
                    purchasePrice: 50.0, // sensible default starting investment
                    datePurchased: Date(),
                    imageData: inputImage?.jpegData(compressionQuality: 0.8)
                )
                modelContext.insert(newItem)
                newSelectedIDs.insert(newItem.id)
                aiMatchedIDs.insert(newItem.id)
            }
        }

        try? modelContext.save()

        self.selectedItemIDs = newSelectedIDs
        self.aiDetectedItemIDs = aiMatchedIDs
        if let summary = analysisResult?.summary {
            self.outfitSummaryText = summary
        }
    }
}
