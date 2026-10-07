import SwiftUI
import SwiftData

struct DailyStylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [WardrobeItem]
    @ObservedObject private var weatherManager = WeatherServiceManager.shared
    @ObservedObject private var stylistEngine = StylistEngine.shared
    @ObservedObject private var currencyManager = CurrencyManager.shared

    @State private var selectedTabMode: StylistTabMode = .today
    @State private var showingSaveLookbookSheet = false
    @State private var customOutfitName = ""
    @State private var showingLoggedCelebration = false
    @State private var loggedCount = 0

    enum StylistTabMode: String, CaseIterable, Identifiable {
        case today = "Today's Stylist"
        case lookbook = "Saved Lookbook"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Segmented Control
                    Picker("Stylist Mode", selection: $selectedTabMode) {
                        ForEach(StylistTabMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    if selectedTabMode == .today {
                        todayStylistContent
                    } else {
                        LookbookView()
                    }
                }
                .padding(.vertical, 14)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("AI Stylist")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        weatherManager.requestLiveWeather()
                        refreshRecommendation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(weatherManager.currentWeather.isLive ? weatherManager.currentWeather.locationName : "Live GPS")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        stylistEngine.shuffleRecommendation(
                            for: items,
                            weather: weatherManager.currentWeather,
                            currencyManager: currencyManager
                        )
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                    }
                }
            }
            .onAppear {
                weatherManager.requestLiveWeather()
                refreshRecommendation()
            }
            .onChange(of: weatherManager.currentWeather) { _, newWeather in
                stylistEngine.generateRecommendation(
                    for: items,
                    weather: newWeather,
                    currencyManager: currencyManager
                )
            }
            .alert("Save to Lookbook", isPresented: $showingSaveLookbookSheet) {
                TextField("Outfit Name", text: $customOutfitName)
                Button("Save") {
                    _ = stylistEngine.saveRecommendationToLookbook(
                        name: customOutfitName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : customOutfitName,
                        in: modelContext
                    )
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save today's curated outfit as a reusable Lookbook combo.")
            }
            .alert("Outfit Logged!", isPresented: $showingLoggedCelebration) {
                Button("Awesome", role: .cancel) {}
            } message: {
                Text("Successfully logged \(loggedCount) pieces for today. Cost-Per-Wear dropped across all worn items!")
            }
        }
    }

    // MARK: - Today's Stylist Content
    @ViewBuilder
    private var todayStylistContent: some View {
        if items.isEmpty {
            emptyWardrobeView
        } else {
            // Weather Card
            weatherBannerCard

            // Weather Scenario Quick Switcher
            weatherScenarioPillRow

            if let rec = stylistEngine.currentRecommendation {
                // Hero CPW Optimization Banner
                heroCPWDropBanner(rec: rec)

                // Curated Outfit Pieces
                curatedOutfitSection(rec: rec)

                // AI Stylist Narrative
                stylistAdviceCard(rec: rec)

                // Action Buttons
                actionButtonsSection(rec: rec)
            } else {
                ProgressView("Curating today's CPW-optimized outfit...")
                    .padding(.vertical, 40)
            }
        }
    }

    // MARK: - Weather Banner Card
    private var weatherBannerCard: some View {
        let weather = weatherManager.currentWeather
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        Text(weather.locationName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if weather.isLive {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: weather.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.caption)

                        Text(weather.conditionDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(weather.temperatureFahrenheit))°F")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text("H: \(Int(weather.highFahrenheit))°")
                        Text("L: \(Int(weather.lowFahrenheit))°")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            // Summary tag
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: weather.temperatureBand.iconName)
                    Text("\(weather.temperatureBand.rawValue) Conditions")
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(weather.temperatureBand.color.opacity(0.15))
                .foregroundStyle(weather.temperatureBand.color)
                .clipShape(Capsule())

                if weather.isRaining {
                    HStack(spacing: 4) {
                        Image(systemName: "umbrella.fill")
                        Text("Rain: \(weather.precipitationChancePercent)%")
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                }

                Spacer()

                Text(weather.summaryAdvice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemGroupedBackground),
                    weather.temperatureBand.color.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(weather.temperatureBand.color.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Weather Scenario Pills
    private var weatherScenarioPillRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WeatherPreset.allCases) { preset in
                    let isSelected = weatherManager.selectedPreset == preset
                    let pillTitle: String = {
                        if preset == .live {
                            return weatherManager.selectedPreset == .live && weatherManager.currentWeather.isLive
                                ? weatherManager.currentWeather.locationName
                                : "Live GPS"
                        }
                        return preset.rawValue
                    }()

                    Button {
                        weatherManager.applyPreset(preset)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: preset.iconName)
                                .font(.caption2)
                            Text(pillTitle)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Hero CPW Drop Banner
    private func heroCPWDropBanner(rec: StylistRecommendation) -> some View {
        Group {
            if let hero = rec.heroItem {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 30, height: 30)

                            Image(systemName: "flame.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("CPW OPTIMIZATION OPPORTUNITY")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.orange)

                            Text(rec.heroHeadline)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Spacer()
                    }

                    // Trajectory Drop Graphic
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current CPW")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(currencyManager.format(hero.costPerWear))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("After Today's Wear")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(currencyManager.format(hero.nextCostPerWear))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }

                        Spacer()

                        Text("-\(currencyManager.format(rec.heroDropAmount)) Drop")
                            .font(.caption.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.18))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.4), .red.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Curated Outfit Section
    private func curatedOutfitSection(rec: StylistRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rec.outfitTitle)
                        .font(.headline)
                    Text("Total combined CPW reduction: \(currencyManager.format(rec.combinedCPWDrop))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(rec.occasionTag)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            // Horizontal Outfit Items Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(rec.suggestedItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    .frame(width: 120, height: 110)

                                if let data = item.imageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(8)
                                        .frame(width: 120, height: 110)
                                } else {
                                    Image(systemName: item.garmentCategory.iconName)
                                        .font(.system(size: 36))
                                        .foregroundStyle(item.garmentCategory.color)
                                        .frame(width: 120, height: 110)
                                }

                                // Category icon badge
                                Image(systemName: item.garmentCategory.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(5)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .foregroundStyle(item.garmentCategory.color)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                                // Drop badge
                                Text("-\(currencyManager.formatCompact(item.cpwDropNextWear))")
                                    .font(.system(size: 9, weight: .black))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .padding(6)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)

                                HStack {
                                    Text(currencyManager.format(item.costPerWear))
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(item.utilityTier.color)

                                    Spacer()

                                    Text("\(item.totalWears)w")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 120)
                            }
                        }
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Stylist Advice Card
    private func stylistAdviceCard(rec: StylistRecommendation) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.purple)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("AI Stylist Rationale")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Apple AI")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }

                Text(rec.stylistAdvice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons Section
    private func actionButtonsSection(rec: StylistRecommendation) -> some View {
        VStack(spacing: 10) {
            // One-Tap Wear Button
            Button {
                logOutfit(rec: rec)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Wear This Outfit Today (1-Tap)")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 3)
            }

            // Secondary Actions
            HStack(spacing: 12) {
                Button {
                    customOutfitName = rec.outfitTitle
                    showingSaveLookbookSheet = true
                } label: {
                    Label("Save to Lookbook", systemImage: "bookmark.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    stylistEngine.shuffleRecommendation(
                        for: items,
                        weather: weatherManager.currentWeather,
                        currencyManager: currencyManager
                    )
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State
    private var emptyWardrobeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(.purple)
                .padding(.top, 40)

            Text("No Clothes in Wardrobe")
                .font(.headline)

            Text("Add tops, bottoms, and outerwear so the AI Stylist can craft weather-aware, CPW-maximizing outfits for you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func refreshRecommendation() {
        stylistEngine.generateRecommendation(
            for: items,
            weather: weatherManager.currentWeather,
            currencyManager: currencyManager
        )
    }

    private func logOutfit(rec: StylistRecommendation) {
        let count = stylistEngine.logCurrentOutfit(in: modelContext, date: Date())
        if count > 0 {
            loggedCount = count
            showingLoggedCelebration = true
        }
    }
}
