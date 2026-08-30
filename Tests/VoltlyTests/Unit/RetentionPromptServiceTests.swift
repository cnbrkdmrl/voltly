#if canImport(XCTest)
import XCTest
@testable import Voltly

final class RetentionPromptServiceTests: XCTestCase {
    func testGeneratePromptReturnsInactivityReminderAndTracksLastSessionDate() {
        let defaults = makeDefaults()
        let service = RetentionPromptService(userDefaults: defaults)
        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23
        let sessionDate = referenceDate.addingTimeInterval(-10 * 24 * 60 * 60)

        let sessions = [
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: sessionDate,
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 320,
                currencyCode: "TRY",
                energyKWh: 28,
                energyIsEstimated: false,
                socStart: 18,
                socEnd: 80,
                isFullCharge: false,
                durationMin: 52,
                odometerKM: 1_000
            )
        ]

        let prompt = service.generatePrompt(
            sessions: sessions,
            goals: [],
            referenceDate: referenceDate
        )

        XCTAssertEqual(prompt?.type, .missingRecentEntry)
        XCTAssertEqual(prompt?.daysSinceLastSession, 10)
        XCTAssertEqual(service.trackedLastSessionDate(), sessionDate)
        XCTAssertEqual(prompt?.notificationPayload.categoryIdentifier, "retention.missing_recent_entry")
    }

    func testGeneratePromptReturnsMonthlySummaryReminderWhenDataIsInsufficient() {
        let defaults = makeDefaults()
        let service = RetentionPromptService(userDefaults: defaults)
        let referenceDate = Date(timeIntervalSince1970: 1_774_440_000) // 2026-03-20

        let sessions = [
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-24 * 60 * 60),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 110,
                currencyCode: "TRY",
                energyKWh: 14,
                energyIsEstimated: false,
                socStart: 32,
                socEnd: 58,
                isFullCharge: false,
                durationMin: 40,
                odometerKM: 2_000
            )
        ]

        let prompt = service.generatePrompt(
            sessions: sessions,
            goals: [],
            referenceDate: referenceDate
        )

        XCTAssertEqual(prompt?.type, .monthlySummaryNeedsData)
        XCTAssertTrue(prompt?.text.contains("yeni şarj kaydı") == true)
    }

    func testGeneratePromptReturnsGoalFollowUpReminderWhenGoalsNeedFreshData() {
        let defaults = makeDefaults()
        let service = RetentionPromptService(userDefaults: defaults)
        let referenceDate = Date(timeIntervalSince1970: 1_774_440_000) // 2026-03-20
        let goal = UserGoal(type: .monthlyChargeEntries, targetValue: 10)

        let sessions = [
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-4 * 24 * 60 * 60),
                chargeMethod: .publicAC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 260,
                currencyCode: "TRY",
                energyKWh: 22,
                energyIsEstimated: false,
                socStart: 20,
                socEnd: 74,
                isFullCharge: false,
                durationMin: 44,
                odometerKM: 4_000
            )
        ]

        let prompt = service.generatePrompt(
            sessions: sessions,
            goals: [goal],
            referenceDate: referenceDate
        )

        XCTAssertEqual(prompt?.type, .goalFollowUpNeeded)
        XCTAssertTrue(prompt?.text.contains("hedefine") == true)
        XCTAssertEqual(prompt?.notificationPayload.categoryIdentifier, "retention.goal_follow_up.entry")
    }

    func testGeneratePromptSuppressesSamePromptWithinTwentyFourHours() {
        let defaults = makeDefaults()
        let service = RetentionPromptService(userDefaults: defaults)
        let referenceDate = Date(timeIntervalSince1970: 1_774_440_000) // 2026-03-20
        let sessions = [
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-24 * 60 * 60),
                chargeMethod: .home,
                stationBrand: "Ev",
                locationName: "Ev",
                priceTotal: 95,
                currencyCode: "TRY",
                energyKWh: 11,
                energyIsEstimated: false,
                socStart: 35,
                socEnd: 55,
                isFullCharge: false,
                durationMin: 36,
                odometerKM: 6_000
            )
        ]

        let first = service.generatePrompt(
            sessions: sessions,
            goals: [],
            referenceDate: referenceDate
        )
        let second = service.generatePrompt(
            sessions: sessions,
            goals: [],
            referenceDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "RetentionPromptServiceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return .standard
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
#endif
