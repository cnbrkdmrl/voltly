#if canImport(XCTest)
import XCTest
@testable import Voltly

final class AppInstallEventTrackerTests: XCTestCase {
    func testTracksAppInstallOnlyOnce() throws {
        let suiteName = "AppInstallEventTrackerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let tracker = TestAnalyticsTracker()
        let installTracker = AppInstallEventTracker(
            analytics: tracker,
            defaults: defaults
        )

        installTracker.trackIfNeeded()
        installTracker.trackIfNeeded()

        XCTAssertEqual(tracker.events, [.appInstall])
    }

    func testFirebaseEventNamesForCoreEvents() {
        XCTAssertEqual(AnalyticsEvent.appInstall.firebaseName, "app_install")
        XCTAssertEqual(AnalyticsEvent.onboardingCompleted.firebaseName, "onboarding_completed")
        XCTAssertEqual(AnalyticsEvent.vehicleCreated.firebaseName, "vehicle_created")
        XCTAssertEqual(AnalyticsEvent.chargeAdded.firebaseName, "charge_added")
        XCTAssertEqual(AnalyticsEvent.monthlyReportShared.firebaseName, "monthly_report_shared")
    }
}

private final class TestAnalyticsTracker: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
#endif
