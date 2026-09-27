import SwiftUI
import SwiftData

struct WardrobeItemCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: WardrobeItem

    @State private var isIncrementing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cutout Image Container
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(height: 150)

                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: 150)
                        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: item.garmentCategory.iconName)
                            .font(.system(size: 40))
                            .foregroundStyle(item.garmentCategory.color.opacity(0.8))
                        Text(item.category)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 150)
                }

                // Category badge overlay top-left
                HStack {
                    Image(systemName: item.garmentCategory.iconName)
                        .font(.caption2)
                        .foregroundStyle(item.garmentCategory.color)
                    Spacer()
                    // CPW Status Badge (Green / Amber / Red)
                    cpwBadge
                }
                .padding(8)
            }

            // Garment Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "$%.2f", item.costPerWear))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(item.utilityTier.color)
                    Text("/ wear")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(item.totalWears)w")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                }
            }
            .padding(.horizontal, 4)

            // Quick action button (+1 Wear)
            Button {
                logWear()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("Wear (+1)")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(isIncrementing ? 0.95 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var cpwBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(item.utilityTier.color)
                .frame(width: 6, height: 6)
            Text(item.utilityTier == .high ? "High" : (item.utilityTier == .moderate ? "Mid" : "Low"))
                .font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .foregroundStyle(item.utilityTier.color)
    }

    private func logWear() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            isIncrementing = true
        }

        let newLog = WearLog(loggedAt: Date(), item: item)
        modelContext.insert(newLog)
        try? modelContext.save()

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation {
                self.isIncrementing = false
            }
        }
    }
}
