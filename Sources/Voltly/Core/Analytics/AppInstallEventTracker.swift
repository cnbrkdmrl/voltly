import Foundation

public final class AppInstallEventTracker {
    private enum Keys {
        static let appInstallTracked = "analytics.app_install.tracked"
    }

    private let analytics: AnalyticsTracking
    private let defaults: UserDefaults

    public init(
        analytics: AnalyticsTracking,
        defaults: UserDefaults = .standard
    ) {
        self.analytics = analytics
        self.defaults = defaults
    }

    public func trackIfNeeded() {
        guard !defaults.bool(forKey: Keys.appInstallTracked) else { return }
        analytics.track(.appInstall)
        defaults.set(true, forKey: Keys.appInstallTracked)
    }
}
