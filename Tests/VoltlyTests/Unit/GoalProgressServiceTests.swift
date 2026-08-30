#if canImport(XCTest)
import XCTest
@testable import Voltly

final class GoalProgressServiceTests: XCTestCase {
    private let service = GoalProgressService()

    func testMakeSnapshotBuildsExpectedGoalItems() {
        let goals = [
            UserGoal(type: .monthlySpending, targetValue: 2_000),
            UserGoal(type: .dcUsageRatio, targetValue: 40),
            UserGoal(type: .monthlyChargeEntries, targetValue: 8)
        ]

        let sessions = [
            makeSession(method: .publicDC, price: 450),
            makeSession(method: .publicAC, price: 300),
            makeSession(method: .home, price: 120),
            makeSession(method: .publicDC, price: 380)
        ]

        let snapshot = service.makeSnapshot(
            goals: goals,
            monthlySessions: sessions,
            currencyCode: "TRY"
        )

        XCTAssertEqual(snapshot.items.count, 3)
        XCTAssertEqual(snapshot.items.first?.type, .dcUsageRatio)
        XCTAssertTrue(snapshot.items.contains { $0.type == .monthlySpending && $0.headline.contains("Hedefine") })
        XCTAssertTrue(snapshot.items.contains { $0.type == .monthlyChargeEntries && $0.detail.contains("4 / 8") })
    }

    func testMakeSnapshotFlagsExceededDCRatioGoal() {
        let goals = [UserGoal(type: .dcUsageRatio, targetValue: 30)]
        let sessions = [
            makeSession(method: .publicDC, price: 400),
            makeSession(method: .publicDC, price: 420),
            makeSession(method: .publicAC, price: 230)
        ]

        let snapshot = service.makeSnapshot(
            goals: goals,
            monthlySessions: sessions,
            currencyCode: "TRY"
        )

        XCTAssertEqual(snapshot.items.first?.tone, .warning)
        XCTAssertTrue(snapshot.items.first?.headline.contains("ustunde") == true)
    }

    private func makeSession(method: ChargeMethod, price: Double) -> ChargingSession {
        ChargingSession(
            vehicleID: UUID(),
            sessionDate: .now,
            chargeMethod: method,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: 30,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            durationMin: 45,
            odometerKM: nil
        )
    }
}
#endif
