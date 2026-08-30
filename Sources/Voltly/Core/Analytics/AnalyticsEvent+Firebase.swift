import Foundation

public extension AnalyticsEvent {
    var firebaseName: String {
        switch self {
        case .appInstall:
            return "app_install"
        case .onboardingCompleted:
            return "onboarding_completed"
        case .vehicleCreated:
            return "vehicle_created"
        case .chargeAdded:
            return "charge_added"
        case .monthlyReportShared:
            return "monthly_report_shared"
        case .dashboardViewed:
            return "dashboard_viewed"
        case .dashboardChartInteracted:
            return "dashboard_chart_interacted"
        case .savingsBadgeViewed:
            return "savings_badge_viewed"
        }
    }

    var firebaseParameters: [String: Any]? {
        nil
    }
}
