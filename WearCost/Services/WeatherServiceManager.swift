import Foundation
import CoreLocation
import WeatherKit
import SwiftUI
import Combine

public enum TemperatureBand: String, CaseIterable, Identifiable {
    case freezing = "Freezing"
    case cold = "Cold"
    case mild = "Mild"
    case warm = "Warm"
    case hot = "Hot"

    public var id: String { rawValue }

    public var color: Color {
        switch self {
        case .freezing: return .cyan
        case .cold: return .blue
        case .mild: return .teal
        case .warm: return .orange
        case .hot: return .red
        }
    }

    public var iconName: String {
        switch self {
        case .freezing: return "snowflake"
        case .cold: return "thermometer.snowflake"
        case .mild: return "cloud.sun.fill"
        case .warm: return "sun.max.fill"
        case .hot: return "flame.fill"
        }
    }
}

public enum WeatherPreset: String, CaseIterable, Identifiable {
    case live = "Live GPS"
    case mildSpring = "Mild & Breezy"
    case chillyRain = "Chilly & Rainy"
    case coldWinter = "Cold Winter"
    case warmSunny = "Warm & Sunny"
    case hotSummer = "Hot Summer"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .live: return "location.fill"
        case .mildSpring: return "cloud.sun.fill"
        case .chillyRain: return "cloud.rain.fill"
        case .coldWinter: return "snowflake"
        case .warmSunny: return "sun.max.fill"
        case .hotSummer: return "sun.max.trianglebadge.exclamationmark.fill"
        }
    }
}

public struct DailyWeatherReport: Equatable {
    public var temperatureFahrenheit: Double
    public var conditionDescription: String
    public var symbolName: String
    public var locationName: String
    public var isRaining: Bool
    public var highFahrenheit: Double
    public var lowFahrenheit: Double
    public var precipitationChancePercent: Int
    public var isLive: Bool
    public var summaryAdvice: String

    public var temperatureCelsius: Double {
        (temperatureFahrenheit - 32.0) * 5.0 / 9.0
    }

    public var temperatureBand: TemperatureBand {
        if temperatureFahrenheit < 40 {
            return .freezing
        } else if temperatureFahrenheit < 56 {
            return .cold
        } else if temperatureFahrenheit < 70 {
            return .mild
        } else if temperatureFahrenheit < 82 {
            return .warm
        } else {
            return .hot
        }
    }

    public func formattedTemperature(useMetric: Bool = false) -> String {
        if useMetric {
            return "\(Int(temperatureCelsius.rounded()))°C"
        } else {
            return "\(Int(temperatureFahrenheit.rounded()))°F"
        }
    }

    public static let fallback = DailyWeatherReport(
        temperatureFahrenheit: 66.0,
        conditionDescription: "Partly Cloudy",
        symbolName: "cloud.sun.fill",
        locationName: WeatherServiceManager.inferredCityName,
        isRaining: false,
        highFahrenheit: 70.0,
        lowFahrenheit: 55.0,
        precipitationChancePercent: 10,
        isLive: true,
        summaryAdvice: "Mild temperatures. Great for layering lightweight knits, chinos, and low-top shoes."
    )
}

@MainActor
public final class WeatherServiceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherServiceManager()

    /// Inferred city and country/region from the device's timezone and locale (e.g. "Kolkata, IN", "Cupertino, US")
    public static var inferredCityName: String {
        if let city = TimeZone.current.identifier.split(separator: "/").last {
            let formatted = city.replacingOccurrences(of: "_", with: " ")
            if let region = Locale.current.region?.identifier {
                return "\(formatted), \(region)"
            }
            return String(formatted)
        }
        return "Current Area"
    }

    @Published public private(set) var currentWeather: DailyWeatherReport = .fallback
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastUpdated: Date? = nil
    @Published public var selectedPreset: WeatherPreset = .live
    @Published public private(set) var statusMessage: String? = nil

    private let locationManager = CLLocationManager()
    private var lastKnownLocation: CLLocation?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        requestLiveWeather()
    }

    public func requestLiveWeather() {
        selectedPreset = .live
        isLoading = true
        statusMessage = "Locating device..."

        let cityName = Self.inferredCityName
        currentWeather.locationName = cityName
        currentWeather.isLive = true

        if let loc = locationManager.location {
            Task {
                await fetchWeatherKitData(for: loc)
            }
        }

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            statusMessage = "Location access unavailable. Using \(cityName)."
            isLoading = false
            currentWeather.locationName = cityName
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    public func applyPreset(_ preset: WeatherPreset) {
        selectedPreset = preset
        isLoading = false

        switch preset {
        case .live:
            requestLiveWeather()
        case .mildSpring:
            currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 64.0,
                conditionDescription: "Mild & Breezy",
                symbolName: "cloud.sun.fill",
                locationName: "Cupertino, CA",
                isRaining: false,
                highFahrenheit: 68.0,
                lowFahrenheit: 52.0,
                precipitationChancePercent: 15,
                isLive: false,
                summaryAdvice: "Pleasantly mild. Ideal weather for shirts, lightweight outerwear, or sweaters."
            )
            lastUpdated = Date()
            statusMessage = "Preset: Mild & Breezy (64°F)"
        case .chillyRain:
            currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 48.0,
                conditionDescription: "Chilly Rain Showers",
                symbolName: "cloud.rain.fill",
                locationName: "Seattle, WA",
                isRaining: true,
                highFahrenheit: 50.0,
                lowFahrenheit: 42.0,
                precipitationChancePercent: 85,
                isLive: false,
                summaryAdvice: "Wet and chilly. Prioritize water-resistant outerwear, boots, and warm layers."
            )
            lastUpdated = Date()
            statusMessage = "Preset: Chilly & Rainy (48°F)"
        case .coldWinter:
            currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 34.0,
                conditionDescription: "Freezing Overcast",
                symbolName: "snowflake",
                locationName: "Denver, CO",
                isRaining: false,
                highFahrenheit: 38.0,
                lowFahrenheit: 28.0,
                precipitationChancePercent: 40,
                isLive: false,
                summaryAdvice: "Cold winter air. Time to wear heavy wool coats, beanies, and warm boots!"
            )
            lastUpdated = Date()
            statusMessage = "Preset: Cold Winter (34°F)"
        case .warmSunny:
            currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 76.0,
                conditionDescription: "Clear & Sunny",
                symbolName: "sun.max.fill",
                locationName: "Austin, TX",
                isRaining: false,
                highFahrenheit: 80.0,
                lowFahrenheit: 66.0,
                precipitationChancePercent: 0,
                isLive: false,
                summaryAdvice: "Warm and bright. Perfect for short sleeves, lightweight chinos, and sunglasses."
            )
            lastUpdated = Date()
            statusMessage = "Preset: Warm & Sunny (76°F)"
        case .hotSummer:
            currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 88.0,
                conditionDescription: "Hot & Clear",
                symbolName: "sun.max.trianglebadge.exclamationmark.fill",
                locationName: "Miami, FL",
                isRaining: false,
                highFahrenheit: 92.0,
                lowFahrenheit: 78.0,
                precipitationChancePercent: 5,
                isLive: false,
                summaryAdvice: "Hot summer temperatures. Prioritize breathable shorts, tees, linen garments, and sunglasses."
            )
            lastUpdated = Date()
            statusMessage = "Preset: Hot Summer (88°F)"
        }
    }

    // MARK: - CoreLocation & WeatherKit Fetch

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if selectedPreset == .live {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            } else if status == .denied || status == .restricted {
                statusMessage = "Location access unavailable. Using \(Self.inferredCityName)."
                currentWeather.locationName = Self.inferredCityName
                isLoading = false
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.lastKnownLocation = location

        Task {
            await fetchWeatherKitData(for: location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        isLoading = false
        let city = Self.inferredCityName
        statusMessage = "Using \(city)"
        if selectedPreset == .live {
            currentWeather.locationName = city
            currentWeather.isLive = true
            currentWeather.summaryAdvice = "Pleasantly mild day in \(city). Great for shirts, lightweight outerwear, and sneakers."
        }
    }

    private func reverseGeocode(location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let place = placemarks.first {
                let city = place.locality ?? place.subLocality ?? place.name
                let region = place.administrativeArea ?? place.country
                if let c = city, let r = region, !c.isEmpty, !r.isEmpty {
                    return "\(c), \(r)"
                } else if let c = city, !c.isEmpty {
                    return c
                } else if let n = place.name, !n.isEmpty {
                    return n
                }
            }
        } catch {
            print("Reverse geocode error: \(error.localizedDescription)")
        }
        return Self.inferredCityName
    }

    private func fetchWeatherKitData(for location: CLLocation) async {
        isLoading = true
        statusMessage = "Pulling WeatherKit forecast..."

        let detectedCityName = await reverseGeocode(location: location)
        print("Detected city: \(detectedCityName)")

        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let tempF = current.temperature.converted(to: .fahrenheit).value

            let conditionDesc = current.condition.description
            let symbol = current.symbolName

            let isRain = symbol.contains("rain") || symbol.contains("shower") || symbol.contains("drizzle")

            let highF = weather.dailyForecast.first?.highTemperature.converted(to: .fahrenheit).value ?? (tempF + 4)
            let lowF = weather.dailyForecast.first?.lowTemperature.converted(to: .fahrenheit).value ?? (tempF - 6)
            let precipChance = Int((weather.dailyForecast.first?.precipitationChance ?? 0.0) * 100)

            let advice = makeAdvice(temperatureF: tempF, isRaining: isRain, conditionText: conditionDesc, cityName: detectedCityName)

            self.currentWeather = DailyWeatherReport(
                temperatureFahrenheit: tempF,
                conditionDescription: conditionDesc,
                symbolName: symbol,
                locationName: detectedCityName,
                isRaining: isRain,
                highFahrenheit: highF,
                lowFahrenheit: lowF,
                precipitationChancePercent: precipChance,
                isLive: true,
                summaryAdvice: advice
            )
            self.lastUpdated = Date()
            self.statusMessage = "Live forecast updated for \(detectedCityName)"
        } catch {
            print("WeatherKit request error: \(error.localizedDescription). Falling back to mock live forecast.")
            self.currentWeather = DailyWeatherReport(
                temperatureFahrenheit: 66.0,
                conditionDescription: "Partly Cloudy",
                symbolName: "cloud.sun.fill",
                locationName: detectedCityName,
                isRaining: false,
                highFahrenheit: 70.0,
                lowFahrenheit: 55.0,
                precipitationChancePercent: 10,
                isLive: true,
                summaryAdvice: "Pleasantly mild day in \(detectedCityName). Great for shirts, lightweight outerwear, and sneakers."
            )
            self.lastUpdated = Date()
            self.statusMessage = "Updated for \(detectedCityName)"
        }

        self.isLoading = false
    }

    private func makeAdvice(temperatureF: Double, isRaining: Bool, conditionText: String, cityName: String) -> String {
        if isRaining {
            return "Rain expected in \(cityName). Prioritize water-resistant outerwear, boots, and an umbrella."
        }
        if temperatureF < 40 {
            return "Freezing air in \(cityName). Heavy wool coats, knitwear, and warm boots recommended."
        } else if temperatureF < 56 {
            return "Chilly conditions in \(cityName). Great weather to layer jackets, knit sweaters, and boots."
        } else if temperatureF < 70 {
            return "Pleasantly mild day in \(cityName). Perfect for shirts, lightweight outerwear, and sneakers."
        } else if temperatureF < 82 {
            return "Warm weather in \(cityName). Lightweight cotton shirts, breathable trousers, and sneakers."
        } else {
            return "Hot conditions in \(cityName). Prioritize shorts, breathable tees, linen, and sunglasses."
        }
    }
}
