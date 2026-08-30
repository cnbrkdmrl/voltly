#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ChargeSessionScoringServiceTests: XCTestCase {
    private let service = ChargeSessionScoringService()

    func testScoreMarksCheapHealthyACSessionAsGood() {
        let vehicle = makeVehicle()
        let session = makeSession(
            id: UUID(),
            daysAgo: 0,
            method: .publicAC,
            price: 250,
            energy: 32,
            startSOC: 18,
            endSOC: 82,
            durationMin: 70
        )
        let history = [
            session,
            makeSession(daysAgo: 2, method: .publicAC, price: 320, energy: 30, startSOC: 22, endSOC: 80, durationMin: 72),
            makeSession(daysAgo: 5, method: .publicAC, price: 315, energy: 29, startSOC: 25, endSOC: 79, durationMin: 74),
            makeSession(daysAgo: 9, method: .publicAC, price: 330, energy: 31, startSOC: 20, endSOC: 81, durationMin: 68)
        ]

        let report = service.score(session: session, vehicle: vehicle, history: history)

        XCTAssertGreaterThanOrEqual(report.overallScore, 7.0)
        XCTAssertTrue([.good, .veryGood].contains(report.label))
        XCTAssertEqual(report.primaryComment, "Bu şarj ortalamandan %27 daha uygun.")
        XCTAssertEqual(ChargeSessionScoringText.sessionBadgeTitle(for: report.label), "İyi seçim")
        XCTAssertTrue(ChargeSessionScoringText.postSaveMessage(for: report).contains("ortalamandan"))
    }

    func testScoreMarksHighCostDCSessionAsExpensive() {
        let vehicle = makeVehicle()
        let session = makeSession(
            id: UUID(),
            daysAgo: 0,
            method: .publicDC,
            price: 520,
            energy: 28,
            startSOC: 14,
            endSOC: 96,
            durationMin: 34
        )
        let history = [
            session,
            makeSession(daysAgo: 1, method: .publicDC, price: 430, energy: 31, startSOC: 20, endSOC: 82, durationMin: 30),
            makeSession(daysAgo: 3, method: .publicDC, price: 440, energy: 32, startSOC: 18, endSOC: 80, durationMin: 31),
            makeSession(daysAgo: 6, method: .publicDC, price: 410, energy: 30, startSOC: 24, endSOC: 78, durationMin: 29),
            makeSession(daysAgo: 8, method: .publicAC, price: 210, energy: 28, startSOC: 26, endSOC: 76, durationMin: 75)
        ]

        let report = service.score(session: session, vehicle: vehicle, history: history)

        XCTAssertEqual(report.label, .expensive)
        XCTAssertEqual(ChargeSessionScoringText.sessionBadgeTitle(for: report.label), "Pahalı seçim")
        XCTAssertTrue(report.insights.contains { $0.message.contains("daha pahalı") })
        XCTAssertTrue(report.insights.contains { $0.message.contains("%90 üstüne") })
    }

    func testScoreMarksEfficiencyAsEstimatedWhenFactoryFallbackIsUsed() {
        let vehicle = makeVehicle()
        let session = makeSession(
            id: UUID(),
            daysAgo: 0,
            method: .home,
            price: 180,
            energy: 24,
            startSOC: 24,
            endSOC: 78,
            durationMin: 210,
            odometerKM: nil
        )

        let report = service.score(session: session, vehicle: vehicle, history: [session])

        XCTAssertEqual(report.efficiencyScore.confidence.source, .estimated)
        XCTAssertTrue(report.insights.contains { $0.message == ChargeSessionScoringText.estimatedEfficiencyComment })
    }

    private func makeVehicle() -> Vehicle {
        Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )
    }

    private func makeSession(
        id: UUID = UUID(),
        daysAgo: Int,
        method: ChargeMethod,
        price: Double,
        energy: Double?,
        startSOC: Double,
        endSOC: Double,
        durationMin: Int?,
        odometerKM: Double? = nil
    ) -> ChargingSession {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate

        return ChargingSession(
            id: id,
            vehicleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
            sessionDate: sessionDate,
            chargeMethod: method,
            stationBrand: method == .home ? "Ev" : "ZES",
            locationName: method == .home ? "Ev Garaji" : "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: startSOC,
            socEnd: endSOC,
            isFullCharge: endSOC >= 99,
            durationMin: durationMin,
            odometerKM: odometerKM
        )
    }
}
#endif
