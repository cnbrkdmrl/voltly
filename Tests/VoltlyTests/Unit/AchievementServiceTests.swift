#if canImport(XCTest)
import XCTest
@testable import Voltly

final class AchievementServiceTests: XCTestCase {
    private let service = AchievementService()

    func testEvaluateUnlocksChargeMilestonesAndMethodBadges() {
        let sessions = makeSessions(
            count: 12,
            startDate: Date(timeIntervalSince1970: 1_763_000_000),
            dayStep: 3
        )

        let result = service.evaluate(
            sessions: sessions,
            previouslyUnlockedIDs: []
        )

        XCTAssertTrue(result.badges.contains { $0.id == "first_charge" && $0.isUnlocked })
        XCTAssertTrue(result.badges.contains { $0.id == "ten_charges" && $0.isUnlocked })
        XCTAssertTrue(result.badges.contains { $0.id == "first_home_charge" && $0.isUnlocked })
        XCTAssertTrue(result.badges.contains { $0.id == "first_ac_charge" && $0.isUnlocked })
        XCTAssertTrue(result.badges.contains { $0.id == "first_dc_charge" && $0.isUnlocked })
        XCTAssertTrue(result.badges.contains { $0.id == "fifty_charges" && $0.isUnlocked == false })
    }

    func testEvaluateUnlocksThousandKWhBadge() {
        let sessions = (0..<15).map { index in
            ChargingSession(
                vehicleID: UUID(),
                sessionDate: Date(timeIntervalSince1970: 1_763_000_000 + Double(index * 86_400)),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 450,
                currencyCode: "TRY",
                energyKWh: 80,
                energyIsEstimated: false,
                socStart: 15,
                socEnd: 88,
                isFullCharge: false,
                durationMin: 58,
                odometerKM: 10_000 + Double(index * 140)
            )
        }

        let result = service.evaluate(sessions: sessions, previouslyUnlockedIDs: [])
        let badge = result.badges.first(where: { $0.id == "thousand_kwh" })

        XCTAssertEqual(badge?.isUnlocked, true)
        XCTAssertEqual(badge?.progress, 1)
    }

    func testEvaluateUnlocksRegularTrackerForRecentSessions() {
        let now = Date(timeIntervalSince1970: 1_763_328_000)
        let sessions = makeRecentSessions(referenceDate: now, count: 12, dayStep: 4)

        let result = service.evaluate(
            sessions: sessions,
            previouslyUnlockedIDs: [],
            referenceDate: now
        )

        XCTAssertTrue(result.badges.contains { $0.id == "regular_tracker" && $0.isUnlocked })
    }

    func testEvaluateNewlyUnlockedRespectsPreviouslyUnlockedSet() {
        let sessions = makeSessions(
            count: 11,
            startDate: Date(timeIntervalSince1970: 1_763_000_000),
            dayStep: 4
        )
        let previous: Set<String> = ["first_charge", "first_ac_charge"]

        let result = service.evaluate(
            sessions: sessions,
            previouslyUnlockedIDs: previous
        )

        XCTAssertFalse(result.newlyUnlockedBadges.contains { $0.id == "first_charge" })
        XCTAssertTrue(result.newlyUnlockedBadges.contains { $0.id == "ten_charges" })
    }

    private func makeSessions(
        count: Int,
        startDate: Date,
        dayStep: Int
    ) -> [ChargingSession] {
        let methods: [ChargeMethod] = [.home, .publicAC, .publicDC]
        var sessions: [ChargingSession] = []
        sessions.reserveCapacity(count)

        for index in 0..<count {
            let sessionDate = startDate.addingTimeInterval(Double(index * dayStep * 86_400))
            let chargeMethod = methods[index % methods.count]
            let priceTotal = 260 + Double(index * 12)
            let energyKWh = 28 + Double(index % 6)
            let odometerKM = 20_000 + Double(index * 120)

            sessions.append(
                ChargingSession(
                    vehicleID: UUID(),
                    sessionDate: sessionDate,
                    chargeMethod: chargeMethod,
                    stationBrand: "ZES",
                    locationName: "Kadikoy",
                    priceTotal: priceTotal,
                    currencyCode: "TRY",
                    energyKWh: energyKWh,
                    energyIsEstimated: false,
                    socStart: 18,
                    socEnd: 80,
                    isFullCharge: false,
                    durationMin: 46,
                    odometerKM: odometerKM
                )
            )
        }

        return sessions
    }

    private func makeRecentSessions(
        referenceDate: Date,
        count: Int,
        dayStep: Int
    ) -> [ChargingSession] {
        let methods: [ChargeMethod] = [.home, .publicAC, .publicDC]
        var sessions: [ChargingSession] = []
        sessions.reserveCapacity(count)

        for index in 0..<count {
            let sessionDate = referenceDate.addingTimeInterval(-Double(index * dayStep * 86_400))
            let chargeMethod = methods[index % methods.count]
            let priceTotal = 300 + Double(index * 10)
            let energyKWh = 25 + Double(index % 5)
            let odometerKM = 35_000 + Double(index * 110)

            sessions.append(
                ChargingSession(
                    vehicleID: UUID(),
                    sessionDate: sessionDate,
                    chargeMethod: chargeMethod,
                    stationBrand: "Trugo",
                    locationName: "Levent",
                    priceTotal: priceTotal,
                    currencyCode: "TRY",
                    energyKWh: energyKWh,
                    energyIsEstimated: false,
                    socStart: 20,
                    socEnd: 82,
                    isFullCharge: false,
                    durationMin: 40,
                    odometerKM: odometerKM
                )
            )
        }

        return sessions
    }
}
#endif
