import SwiftUI
import SwiftData

struct OutfitCardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var currencyManager = CurrencyManager.shared
    let outfit: SavedOutfit

    @State private var showingLoggedAlert = false
    @State private var recentlyLogged = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Name & Occasion Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(outfit.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(outfit.occasion)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())

                        if let lastWorn = outfit.lastWorn {
                            Text("Worn \(lastWorn.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never worn")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button(role: .destructive) {
                        deleteOutfit()
                    } label: {
                        Label("Delete Outfit", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // Garments Horizontal Thumbnail Strip
            if let items = outfit.items, !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(items) { item in
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                        .frame(width: 58, height: 58)

                                    if let imageData = item.imageData, let img = UIImage(data: imageData) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(4)
                                            .frame(width: 58, height: 58)
                                    } else {
                                        Image(systemName: item.garmentCategory.iconName)
                                            .font(.system(size: 20))
                                            .foregroundStyle(item.garmentCategory.color)
                                    }
                                }

                                Text(item.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                                    .frame(width: 58)
                            }
                        }
                    }
                }
            }

            Divider()

            // Metrics & One-Tap Log Button
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOTAL CPW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text(currencyManager.format(outfit.averageCPW))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ThresholdManager.shared.tier(for: outfit.averageCPW).color)

                    let drop = outfit.combinedCPWDrop
                    if drop > 0 {
                        Text("-\(currencyManager.format(drop)) if worn")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // One-Tap Wear Logging Button
                Button {
                    logOutfitWear()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: recentlyLogged ? "checkmark" : "plus.circle.fill")
                            .font(.subheadline.weight(.bold))

                        Text(recentlyLogged ? "Outfit Logged!" : "Log Outfit (1-Tap)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(recentlyLogged ? Color.green : Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.3), value: recentlyLogged)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func logOutfitWear() {
        let count = outfit.logWear(in: modelContext, date: Date())
        guard count > 0 else { return }

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.success)

        withAnimation {
            recentlyLogged = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                recentlyLogged = false
            }
        }
    }

    private func deleteOutfit() {
        modelContext.delete(outfit)
        try? modelContext.save()
    }
}
