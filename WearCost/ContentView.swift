import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WardrobeGridView()
                .tabItem {
                    Label("Wardrobe", systemImage: "hanger")
                }
                .tag(0)

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
    }
}

#Preview {
    let container = SampleData.createSampleContainer()
    return ContentView()
        .modelContainer(container)
}
