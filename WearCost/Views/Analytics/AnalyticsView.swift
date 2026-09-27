import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query private var items: [WardrobeItem]
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @ObservedObject private var thresholdManager = ThresholdManager.shared
    @State private var selectedChartMode: ChartMode = .scatter

    enum ChartMode: String, CaseIterable, Identifiable {
        case scatter = "Price vs. Wears"
        case rankings = "Top & Least Worn"
        case categories = "Category Breakdown"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if items.isEmpty {
                        emptyAnalyticsView
                    } else {
                        // Portfolio Top KPI Cards
                        portfolioKPISection

                        // Utility Tier Distribution Bar
                        tierDistributionSection

                        // Mode Selector
                        Picker("Chart View", selection: $selectedChartMode) {
                            ForEach(ChartMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        // Main Dynamic Chart Card
                        chartContainerView

                        // Wardrobe ROI & High Impact Insights
                        insightsSection
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Analytics")
        }
    }

    // MARK: - Portfolio KPI Cards
    private var portfolioKPISection: some View {
        let totalInvestment = items.reduce(0.0) { $0 + $1.purchasePrice }
        let totalWears = items.reduce(0) { $0 + $1.totalWears }
        let portfolioCPW = totalWears > 0 ? (totalInvestment / Double(totalWears)) : totalInvestment

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Portfolio Average CPW
                VStack(alignment: .leading, spacing: 6) {
                    Text("PORTFOLIO CPW")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currencyManager.format(portfolioCPW))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(thresholdManager.tier(for: portfolioCPW).color)
                        Text("/ wear")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Aggregate Investment / Wears")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // Total Investment
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL SPEND")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(currencyManager.formatCompact(totalInvestment))
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    Text("\(items.count) total garments")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            // Total wears banner
            HStack {
                Image(systemName: "figure.walk.motion")
                    .foregroundStyle(.tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalWears) Total Wears Logged")
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: "Average %.1f wears per wardrobe piece", items.isEmpty ? 0 : Double(totalWears) / Double(items.count)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Utility Tier Distribution
    private var tierDistributionSection: some View {
        let highCount = items.filter { $0.utilityTier == .high }.count
        let midCount = items.filter { $0.utilityTier == .moderate }.count
        let lowCount = items.filter { $0.utilityTier == .low }.count
        let total = max(1, items.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Utility Breakdown")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(highCount) High • \(midCount) Mid • \(lowCount) Low")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Proportional Multi-Segment Bar
            GeometryReader { geo in
                HStack(spacing: 3) {
                    if highCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: max(8, geo.size.width * CGFloat(highCount) / CGFloat(total)))
                    }
                    if midCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: max(8, geo.size.width * CGFloat(midCount) / CGFloat(total)))
                    }
                    if lowCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: max(8, geo.size.width * CGFloat(lowCount) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 12)

            HStack(spacing: 16) {
                Label("High (<\(currencyManager.formatCompact(thresholdManager.highThreshold)))", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Label("Mid (\(currencyManager.formatCompact(thresholdManager.highThreshold))-\(currencyManager.formatCompact(thresholdManager.moderateThreshold)))", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Label("Low (>\(currencyManager.formatCompact(thresholdManager.moderateThreshold)))", systemImage: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Dynamic Chart Container
    @ViewBuilder
    private var chartContainerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedChartMode {
            case .scatter:
                scatterPlotSection
            case .rankings:
                topVsLeastWornSection
            case .categories:
                categoryBreakdownSection
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
    }

    // MARK: - Scatter Plot (Price vs. Wears with Target Trajectory Lines)
    private var scatterPlotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Price vs. Wear Trajectories")
                        .font(.headline)
                    Text("Points below curves satisfy target CPW goals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            let maxPrice = max(thresholdManager.moderateThreshold * 10, (items.map(\.purchasePrice).max() ?? 100.0) * 1.1)
            let maxWears = max(20, (items.map(\.totalWears).max() ?? 20) + 5)

            let goalHigh = trajectoryPoints(targetCPW: thresholdManager.highThreshold, maxWears: Double(maxWears), maxPrice: maxPrice)
            let goalModerate = trajectoryPoints(targetCPW: thresholdManager.moderateThreshold, maxWears: Double(maxWears), maxPrice: maxPrice)

            Chart {
                // Goal Line: High Utility CPW Target Trajectory
                ForEach(goalHigh, id: \.id) { pt in
                    LineMark(
                        x: .value("Total Wears", pt.wears),
                        y: .value("Purchase Price", pt.price),
                        series: .value("Trajectory", "\(currencyManager.formatCompact(thresholdManager.highThreshold)) Goal")
                    )
                    .foregroundStyle(.green.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }

                // Goal Line: Moderate Utility CPW Target Trajectory
                ForEach(goalModerate, id: \.id) { pt in
                    LineMark(
                        x: .value("Total Wears", pt.wears),
                        y: .value("Purchase Price", pt.price),
                        series: .value("Trajectory", "\(currencyManager.formatCompact(thresholdManager.moderateThreshold)) Goal")
                    )
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                }

                // Wardrobe Item Scatter Points
                ForEach(items) { item in
                    PointMark(
                        x: .value("Total Wears", Double(item.totalWears)),
                        y: .value("Purchase Price", item.purchasePrice)
                    )
                    .foregroundStyle(item.utilityTier.color)
                    .symbolSize(item.totalWears > 50 ? 120 : 70)
                    .annotation(position: .top, alignment: .center) {
                        Text(item.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)")
                        } else if let dblVal = value.as(Double.self) {
                            Text("\(Int(dblVal.rounded()))")
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(currencyManager.formatCompact(doubleValue))
                        }
                    }
                }
            }
            .chartYScale(domain: 0...maxPrice)
            .chartXScale(domain: 0...Double(maxWears))
            .frame(height: 280)
            .clipped()

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 14, height: 2)
                    Text("\(currencyManager.format(thresholdManager.highThreshold)) / wear line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 2)
                    Text("\(currencyManager.format(thresholdManager.moderateThreshold)) / wear line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trajectoryPoints(targetCPW: Double, maxWears: Double, maxPrice: Double) -> [(id: Int, wears: Double, price: Double)] {
        guard targetCPW > 0, maxWears > 0, maxPrice > 0 else { return [] }
        let endWears = min(maxWears, maxPrice / targetCPW)
        let endPrice = min(maxPrice, endWears * targetCPW)
        return [
            (id: 0, wears: 0.0, price: 0.0),
            (id: 1, wears: endWears, price: endPrice)
        ]
    }

    // MARK: - Bar Charts: Top 5 vs Least 5 Worn
    private var topVsLeastWornSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            let sortedByWears = items.sorted(by: { $0.totalWears > $1.totalWears })
            let top5 = Array(sortedByWears.prefix(5))
            let least5 = Array(sortedByWears.reversed().prefix(5))

            // Top 5 Most Worn
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Top 5 Most Worn Pieces")
                        .font(.subheadline.weight(.semibold))
                }

                Chart(top5) { item in
                    BarMark(
                        x: .value("Wears", item.totalWears),
                        y: .value("Garment", item.name)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.totalWears)w")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(max(3, top5.count)) * 36)
            }

            Divider()

            // Least 5 Worn
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.arrow.trianglehead.counterclockwise.rotate.90")
                        .foregroundStyle(.orange)
                    Text("Least 5 Worn (Need Attention)")
                        .font(.subheadline.weight(.semibold))
                }

                Chart(least5) { item in
                    BarMark(
                        x: .value("Wears", item.totalWears),
                        y: .value("Garment", item.name)
                    )
                    .foregroundStyle(Color.red.opacity(0.7).gradient)
                    .annotation(position: .trailing) {
                        Text("\(item.totalWears)w • \(currencyManager.format(item.costPerWear))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(max(3, least5.count)) * 36)
            }
        }
    }

    // MARK: - Category Breakdown
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Category Spend & Utilization")
                .font(.headline)

            let categoryStats: [(category: GarmentCategory, spend: Double, wears: Int)] = GarmentCategory.allCases.compactMap { cat in
                let categoryItems = items.filter { $0.category == cat.rawValue }
                guard !categoryItems.isEmpty else { return nil }
                let spend = categoryItems.reduce(0.0) { $0 + $1.purchasePrice }
                let wears = categoryItems.reduce(0) { $0 + $1.totalWears }
                return (cat, spend, wears)
            }

            Chart(categoryStats, id: \.category.rawValue) { stat in
                BarMark(
                    x: .value("Category", stat.category.rawValue),
                    y: .value("Investment (\(currencyManager.symbol))", stat.spend)
                )
                .foregroundStyle(stat.category.color.gradient)
                .annotation(position: .top) {
                    Text(currencyManager.formatCompact(stat.spend))
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .frame(height: 200)

            // Category summary table
            VStack(spacing: 8) {
                ForEach(categoryStats, id: \.category.rawValue) { stat in
                    HStack {
                        Image(systemName: stat.category.iconName)
                            .foregroundStyle(stat.category.color)
                            .frame(width: 20)
                        Text(stat.category.rawValue)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(currencyManager.format(stat.spend))
                                .font(.caption.weight(.bold))
                            Text("\(stat.wears) wears")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Wardrobe Insights & High Impact
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mindful Consumption Insights")
                .font(.headline)
                .padding(.horizontal, 4)

            // Best Value Champion
            if let best = items.filter({ $0.totalWears > 0 }).min(by: { $0.costPerWear < $1.costPerWear }) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best Value Champion")
                            .font(.subheadline.weight(.bold))
                        Text("\(best.name) at \(currencyManager.format(best.costPerWear)) / wear (\(best.totalWears) wears)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            // Highest Opportunity Piece
            if let opportunity = items.filter({ $0.utilityTier == .low }).max(by: { $0.purchasePrice > $1.purchasePrice }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.heart.fill")
                        .font(.title2)
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Highest Opportunity")
                            .font(.subheadline.weight(.bold))
                        Text("\(opportunity.name) is at \(currencyManager.format(opportunity.costPerWear))/wear. Wear it \(opportunity.wearsNeeded(forTargetCPW: thresholdManager.moderateThreshold)) more times to reach moderate utility!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyAnalyticsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .padding(.top, 40)

            Text("No Analytics Available Yet")
                .font(.headline)

            Text("Add garments and log wear events to reveal Cost-Per-Wear trajectory plots, utility rankings, and category breakdowns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
