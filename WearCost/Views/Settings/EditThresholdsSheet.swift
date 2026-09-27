import SwiftUI

/// Sheet allowing the user to configure custom formula thresholds for High, Moderate, and Low CPW tiers.
struct EditThresholdsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared

    @State private var highText: String = ""
    @State private var moderateText: String = ""
    @State private var showingResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Overview Explanation
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Customize Utility Thresholds")
                            .font(.headline)

                        Text("Set the Cost-Per-Wear (CPW) price targets that define when a garment transitions between High, Moderate, and Low utility for your personal budget and chosen currency.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Section 2: Input Thresholds
                Section {
                    // High Utility Cutoff
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            Text("High Utility Cutoff (Max CPW)")
                                .font(.subheadline.weight(.semibold))
                        }

                        HStack {
                            Text(currencyManager.symbol)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("0.00", text: $highText)
                                .keyboardType(.decimalPad)
                                .font(.body.monospacedDigit())

                            // Quick adjust buttons
                            HStack(spacing: 8) {
                                Button {
                                    adjustHigh(by: -stepAmount)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    adjustHigh(by: stepAmount)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Items below this CPW are classified as High Utility.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    // Moderate Utility Cutoff
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                            Text("Moderate Utility Cutoff (Max CPW)")
                                .font(.subheadline.weight(.semibold))
                        }

                        HStack {
                            Text(currencyManager.symbol)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)

                            TextField("0.00", text: $moderateText)
                                .keyboardType(.decimalPad)
                                .font(.body.monospacedDigit())

                            // Quick adjust buttons
                            HStack(spacing: 8) {
                                Button {
                                    adjustModerate(by: -stepAmount)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    adjustModerate(by: stepAmount)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Items with CPW between High and Moderate are Moderate Utility. Items above this are Low Utility.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Formula Cutoff Values")
                } footer: {
                    if !isValid {
                        Text("Moderate utility cutoff must be strictly greater than High utility cutoff, and both must be positive.")
                            .foregroundStyle(.red)
                    }
                }

                // Section 3: Live Preview
                Section("Live Formula Preview") {
                    let highVal = parsedHigh ?? thresholdManager.highThreshold
                    let modVal = parsedModerate ?? thresholdManager.moderateThreshold

                    HStack {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("High Utility")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("< \(currencyManager.format(highVal)) / wear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Circle().fill(Color.orange).frame(width: 10, height: 10)
                        Text("Moderate Utility")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(currencyManager.format(highVal)) – \(currencyManager.format(modVal)) / wear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    HStack {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Low Utility")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("> \(currencyManager.format(modVal)) / wear")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }

                // Section 4: Presets & Defaults
                Section("Presets & Suggestions") {
                    let recommended = ThresholdManager.recommendedDefaults(for: currencyManager.selectedCurrencyCode)
                    Button {
                        applyValues(high: recommended.high, moderate: recommended.moderate)
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Color.accentColor)
                            Text("Recommended for \(currencyManager.selectedCurrencyCode)")
                            Spacer()
                            Text("(\(currencyManager.format(recommended.high, includeDecimals: false)) / \(currencyManager.format(recommended.moderate, includeDecimals: false)))")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        applyValues(high: 2.0, moderate: 10.0)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.secondary)
                            Text("Standard Baseline Defaults")
                            Spacer()
                            Text("(\(currencyManager.symbol)2.00 / \(currencyManager.symbol)10.00)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Utility Thresholds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                highText = formatForInput(thresholdManager.highThreshold)
                moderateText = formatForInput(thresholdManager.moderateThreshold)
            }
        }
    }

    private var parsedHigh: Double? {
        Double(highText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedModerate: Double? {
        Double(moderateText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let h = parsedHigh, let m = parsedModerate else { return false }
        return h > 0 && m > h
    }

    private var stepAmount: Double {
        let currentHigh = parsedHigh ?? thresholdManager.highThreshold
        if currentHigh >= 1000 {
            return 100
        } else if currentHigh >= 100 {
            return 10
        } else if currentHigh >= 10 {
            return 1
        } else {
            return 0.5
        }
    }

    private func adjustHigh(by delta: Double) {
        let current = parsedHigh ?? thresholdManager.highThreshold
        let newHigh = max(0.5, current + delta)
        highText = formatForInput(newHigh)
    }

    private func adjustModerate(by delta: Double) {
        let current = parsedModerate ?? thresholdManager.moderateThreshold
        let newMod = max(1.0, current + delta)
        moderateText = formatForInput(newMod)
    }

    private func applyValues(high: Double, moderate: Double) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation {
            highText = formatForInput(high)
            moderateText = formatForInput(moderate)
        }
    }

    private func formatForInput(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func saveChanges() {
        guard let h = parsedHigh, let m = parsedModerate, isValid else { return }

        thresholdManager.setCustomThresholds(high: h, moderate: m)

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismiss()
    }
}
