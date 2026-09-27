import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WardrobeItem]
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared

    @State private var showingResetAlert = false
    @State private var showingSampleDataAlert = false
    @State private var showingEditThresholds = false

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Currency & Regional Preferences
                Section {
                    NavigationLink {
                        CurrencySelectionView()
                    } label: {
                        HStack {
                            Label {
                                Text("Currency")
                            } icon: {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                if let flag = currencyManager.currentCurrency.flag {
                                    Text(flag)
                                }
                                Text("\(currencyManager.currentCurrency.code) (\(currencyManager.currentCurrency.symbol))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Currency & Region")
                } footer: {
                    Text("Select your preferred currency for garment valuation, cost-per-wear tracking, and charts.")
                }

                // Section 2: Daily Wear Logging Reminders
                Section {
                    Toggle("Nightly Outfit Reminder", isOn: $notificationManager.isReminderEnabled)
                        .onChange(of: notificationManager.isReminderEnabled) { _, isEnabled in
                            if isEnabled && !notificationManager.isAuthorized {
                                Task {
                                    _ = await notificationManager.requestAuthorization()
                                }
                            }
                        }

                    if notificationManager.isReminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $notificationManager.reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    if !notificationManager.isAuthorized && notificationManager.isReminderEnabled {
                        Button("Grant Notification Permission") {
                            Task {
                                _ = await notificationManager.requestAuthorization()
                            }
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Routine Wear Logging")
                } footer: {
                    Text("Receive a scheduled daily alert to log the outfit pieces you wore today.")
                }

                // Section 3: What is Cost Per Wear (CPW) & Configurable Formula Thresholds
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The Golden Formula")
                            .font(.subheadline.weight(.semibold))

                        Text("Cost Per Wear = Purchase Price ÷ Total Wears")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.vertical, 2)

                        Text("Every time you wear a piece of clothing, its actual cost per use drops. Tracking your CPW encourages mindful consumption, highlights underutilized garments, and proves the value of high-quality essentials.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("High Utility (< \(currencyManager.format(thresholdManager.highThreshold))/wear)")
                            .font(.caption)
                        Spacer()
                    }

                    HStack {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Moderate Utility (\(currencyManager.format(thresholdManager.highThreshold)) - \(currencyManager.format(thresholdManager.moderateThreshold))/wear)")
                            .font(.caption)
                        Spacer()
                    }

                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Low Utility (> \(currencyManager.format(thresholdManager.moderateThreshold))/wear)")
                            .font(.caption)
                        Spacer()
                    }

                    Button {
                        showingEditThresholds = true
                    } label: {
                        HStack {
                            Label("Edit Formula Thresholds", systemImage: "slider.horizontal.3")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.top, 4)
                } header: {
                    HStack {
                        Text("Cost Per Wear & Thresholds")
                        Spacer()
                        Button("Edit") {
                            showingEditThresholds = true
                        }
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                    }
                } footer: {
                    Text("Customize your CPW cutoffs to reflect your currency, budget, or lifestyle preferences.")
                }

                // Section 4: Data Management & Testing
                Section {
                    Button {
                        showingSampleDataAlert = true
                    } label: {
                        Label("Populate Sample Wardrobe", systemImage: "sparkles")
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Clear All Wardrobe Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data & Testing")
                } footer: {
                    Text("100% offline and on-device. No cloud sync, third-party trackers, or network calls.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingEditThresholds) {
                EditThresholdsSheet()
            }
            .confirmationDialog(
                "Populate Sample Wardrobe?",
                isPresented: $showingSampleDataAlert,
                titleVisibility: .visible
            ) {
                Button("Add 10 Sample Items") {
                    loadSampleData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will insert sample garments across all categories with realistic wear history.")
            }
            .confirmationDialog(
                "Clear All Wardrobe Data?",
                isPresented: $showingResetAlert,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All garments and wear logs will be permanently deleted.")
            }
        }
    }

    private func loadSampleData() {
        SampleData.insertSampleItems(into: modelContext)
    }

    private func clearAllData() {
        for item in items {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}
