import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WardrobeItem]
    @ObservedObject private var notificationManager = NotificationManager.shared

    @State private var showingResetAlert = false
    @State private var showingSampleDataAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Daily Wear Logging Reminders
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

                // Section 2: What is Cost Per Wear (CPW)
                Section("About Cost Per Wear (CPW)") {
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
                        Text("High Utility (< $2.00/wear)")
                            .font(.caption)
                        Spacer()
                    }

                    HStack {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Moderate Utility ($2.00 - $10.00/wear)")
                            .font(.caption)
                        Spacer()
                    }

                    HStack {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Low Utility (> $10.00/wear)")
                            .font(.caption)
                        Spacer()
                    }
                }

                // Section 3: Data Management & Testing
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
