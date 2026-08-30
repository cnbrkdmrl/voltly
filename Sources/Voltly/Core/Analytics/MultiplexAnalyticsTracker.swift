import Foundation

public final class MultiplexAnalyticsTracker: AnalyticsTracking {
    private let trackers: [AnalyticsTracking]

    public init(trackers: [AnalyticsTracking]) {
        self.trackers = trackers
    }

    public func track(_ event: AnalyticsEvent) {
        trackers.forEach { $0.track(event) }
    }
}
