import Foundation

public final class TelemetryCenter: @unchecked Sendable {
    public static let shared = TelemetryCenter()

    public let analytics: AnalyticsTracking
    public let crashReporter: CrashReporting

    private let appInstallTracker: AppInstallEventTracker

    private init() {
        if FirebaseBootstrapper.isAvailableInCurrentBuild {
            let firebaseTracker = FirebaseAnalyticsTracker()
            analytics = MultiplexAnalyticsTracker(trackers: [firebaseTracker])
            crashReporter = FirebaseCrashReporter(fallback: NoopCrashReporter())
        } else {
            analytics = NoopAnalyticsTracker()
            crashReporter = NoopCrashReporter()
        }
        appInstallTracker = AppInstallEventTracker(analytics: analytics)
    }

    public func configureOnLaunch() {
        FirebaseBootstrapper.configureIfNeeded()
        guard FirebaseBootstrapper.isConfigured else { return }
        appInstallTracker.trackIfNeeded()
        crashReporter.log("Telemetry initialized")
    }
}
