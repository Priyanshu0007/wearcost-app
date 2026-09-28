import Foundation

/// Defines the application environment / flavor.
public enum AppEnvironment: String, CaseIterable, Sendable {
    case development = "Development"
    case production = "Production"

    /// The active environment determined at compile-time by the build configuration.
    public static let current: AppEnvironment = {
        #if DEVELOPMENT
        return .development
        #else
        return .production
        #endif
    }()

    public var isDevelopment: Bool {
        self == .development
    }

    public var isProduction: Bool {
        self == .production
    }

    /// The app display name for this flavor.
    public var appDisplayName: String {
        switch self {
        case .development:
            return "WearCost Dev"
        case .production:
            return "WearCost"
        }
    }

    /// Bundle identifier suffix for this flavor.
    public var bundleIdentifierSuffix: String {
        switch self {
        case .development:
            return ".dev"
        case .production:
            return ""
        }
    }
}
