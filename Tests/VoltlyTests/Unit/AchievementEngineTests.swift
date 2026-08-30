#if canImport(XCTest)
import XCTest
@testable import Voltly

final class AchievementEngineTests: XCTestCase {
    private let service = AchievementService()

    func testEvaluateCreatesBehaviorBadgesForHealthyWindowAndConsistency() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_200_000)
        let sessions = (0..<5).map { index in
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-Double(index * 2 * 86_400)),
                chargeMethod: index % 2 == 0 ? .publicAC : .home,
                priceTotal: 250,
                energyKWh: 20,
                socStart: 20,
                socEnd: 80
            )
        }

        let evaluation = service.evaluate(
            sessions: sessions,
            previouslyUnlockedIDs: [],
            referenceDate: referenceDate
        )

        XCTAssertTrue(evaluation.badges.contains { $0.id == "consistent_tracking" && $0.isUnlocked })
        XCTAssertTrue(evaluation.badges.contains { $0.id == "efficient_window" && $0.isUnlocked })
    }

    func testEvaluateCreatesInProgressBehaviorBadgeForCostDrop() {
        let referenceDate = Date(timeIntervalSince1970: 1_775_200_000)
        let previousSessions = (0..<4).map { index in
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-Double((40 + index) * 86_400)),
                chargeMethod: .publicDC,
                priceTotal: 400,
                energyKWh: 20,
                socStart: 18,
                socEnd: 82
            )
        }
        let recentSessions = (0..<4).map { index in
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: referenceDate.addingTimeInterval(-Double(index * 5 * 86_400)),
                chargeMethod: .publicAC,
                priceTotal: 240,
                energyKWh: 24,
                socStart: 20,
                socEnd: 78
            )
        }

        let evaluation = service.evaluate(
            sessions: previousSessions + recentSessions,
            previouslyUnlockedIDs: [],
            referenceDate: referenceDate
        )

        XCTAssertTrue(evaluation.badges.contains { $0.id == "cost_drop" })
        XCTAssertTrue(evaluation.badges.contains { $0.id == "ac_home_improver" })
    }
}
#endif
