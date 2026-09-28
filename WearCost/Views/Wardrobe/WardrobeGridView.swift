import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable, Identifiable {
    case cpwAscending = "CPW: Low to High"
    case cpwDescending = "CPW: High to Low"
    case wearsDescending = "Most Worn"
    case priceDescending = "Highest Price"
    case newest = "Recently Added"

    var id: String { rawValue }
}

struct WardrobeGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WardrobeItem]
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared

    @Namespace private var heroNamespace

    @State private var selectedCategory: String? = nil
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .cpwAscending
    @State private var showingAddSheet = false
    @State private var showingDailyLogSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category Filter Pills
                    categoryFilterBar

                    // Portfolio mini-banner
                    portfolioOverviewCard

                    // Main Items Grid or Empty State
                    if filteredItems.isEmpty {
                        emptyStateView
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredItems) { item in
                                NavigationLink(value: item) {
                                    WardrobeItemCardView(item: item)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: item.id, in: heroNamespace) { configuration in
                                    configuration
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search wardrobe items")
            .navigationTitle("Wardrobe")
            .navigationDestination(for: WardrobeItem.self) { item in
                ItemDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: heroNamespace))
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingDailyLogSheet = true
                    } label: {
                        Label("Daily Outfit", systemImage: "sparkles")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }

                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddItemSheetView()
            }
            .sheet(isPresented: $showingDailyLogSheet) {
                DailyLogSheetView()
            }
        }
    }

    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    count: items.count
                ) {
                    selectedCategory = nil
                }

                ForEach(GarmentCategory.allCases) { category in
                    let categoryCount = items.filter { $0.category == category.rawValue }.count
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.iconName,
                        isSelected: selectedCategory == category.rawValue,
                        count: categoryCount,
                        activeColor: category.color
                    ) {
                        selectedCategory = category.rawValue
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Portfolio Overview Card
    private var portfolioOverviewCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WARDROBE VALUE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                let totalSpent = items.reduce(0.0) { $0 + $1.purchasePrice }
                Text(currencyManager.formatCompact(totalSpent))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("AVG CPW")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                let avgCPW = items.isEmpty ? 0.0 : (items.reduce(0.0) { $0 + $1.costPerWear } / Double(items.count))
                Text(currencyManager.format(avgCPW))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(thresholdManager.tier(for: avgCPW).color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL WEARS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                let totalWears = items.reduce(0) { $0 + $1.totalWears }
                Text("\(totalWears)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedCategory == nil ? "hanger" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text(items.isEmpty ? "Your Wardrobe is Empty" : "No Matching Items")
                .font(.headline)

            Text(items.isEmpty
                 ? "Add your first garment cutout to start tracking your Cost-Per-Wear metrics."
                 : "Try changing your search term or category filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if items.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add First Garment", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Filtered & Sorted Items
    private var filteredItems: [WardrobeItem] {
        var result = items

        if let selectedCategory = selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOption {
        case .cpwAscending:
            result.sort { $0.costPerWear < $1.costPerWear }
        case .cpwDescending:
            result.sort { $0.costPerWear > $1.costPerWear }
        case .wearsDescending:
            result.sort { $0.totalWears > $1.totalWears }
        case .priceDescending:
            result.sort { $0.purchasePrice > $1.purchasePrice }
        case .newest:
            result.sort { $0.datePurchased > $1.datePurchased }
        }

        return result
    }
}

// MARK: - Category Pill Component
struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    var activeColor: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? activeColor : Color(uiColor: .secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: isSelected ? activeColor.opacity(0.25) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
