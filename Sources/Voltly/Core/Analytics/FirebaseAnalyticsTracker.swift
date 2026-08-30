import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

public final class FirebaseAnalyticsTracker: AnalyticsTracking {
    private let fallback: AnalyticsTracking?

    public init(fallback: AnalyticsTracking? = nil) {
        self.fallback = fallback
    }

    public func track(_ event: AnalyticsEvent) {
        #if canImport(FirebaseAnalytics)
        guard FirebaseBootstrapper.isConfigured else {
            fallback?.track(event)
            return
        }
        Analytics.logEvent(event.firebaseName, parameters: event.firebaseParameters)
        #else
        fallback?.track(event)
        #endif
    }
}
