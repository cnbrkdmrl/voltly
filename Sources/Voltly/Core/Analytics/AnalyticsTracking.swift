import Foundation

public protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
}

public enum AnalyticsEvent: Equatable {
    case appInstall
    case onboardingCompleted
    case vehicleCreated
    case chargeAdded
    case monthlyReportShared
    case dashboardViewed
    case dashboardChartInteracted
    case savingsBadgeViewed
}

public final class NoopAnalyticsTracker: AnalyticsTracking {
    public init() {}

    public func track(_ event: AnalyticsEvent) {}
}
