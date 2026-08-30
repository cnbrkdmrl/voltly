#if canImport(XCTest)
import XCTest
@testable import Voltly

final class ChargeInsightServiceTests: XCTestCase {
    private let service = ChargeInsightService()

    func testAnalyzeComputesUsageRatiosAndRollingWindows() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000) // 2025-11-19 approx fixed
        let sessions = [
            makeSession(daysAgo: 2, method: .publicDC, price: 500, energy: 40, odometer: 10_000, startSOC: 15, endSOC: 80, duration: 35),
            makeSession(daysAgo: 6, method: .publicAC, price: 240, energy: 30, odometer: 10_220, startSOC: 28, endSOC: 82, duration: 90),
            makeSession(daysAgo: 10, method: .home, price: 180, energy: 28, odometer: 10_430, startSOC: 34, endSOC: 78, duration: 240),
            makeSession(daysAgo: 18, method: .publicDC, price: 470, energy: 38, odometer: 10_690, startSOC: 12, endSOC: 76, duration: 33),
            makeSession(daysAgo: 27, method: .home, price: 160, energy: 24, odometer: 10_910, startSOC: 26, endSOC: 74, duration: 210),
            makeSession(daysAgo: 41, method: .publicAC, price: 220, energy: 26, odometer: 11_140, startSOC: 30, endSOC: 79, duration: 95),
            makeSession(daysAgo: 48, method: .home, price: 150, energy: 22, odometer: 11_330, startSOC: 35, endSOC: 72, duration: 200)
        ]

        let report = service.analyze(vehicle: vehicle, sessions: sessions, referenceDate: referenceDate)

        XCTAssertEqual(report.overall.sessionCount, 7)
        XCTAssertEqual(report.lastFiveSessions.sessionCount, 5)
        XCTAssertEqual(report.lastThirtyDays.sessionCount, 5)
        XCTAssertEqual(report.previousThirtyDays.sessionCount, 2)
        XCTAssertEqual(Int((report.usageRatios.dcRatio.value ?? 0).rounded()), 29)
        XCTAssertEqual(Int((report.usageRatios.acRatio.value ?? 0).rounded()), 29)
        XCTAssertEqual(Int((report.usageRatios.homeRatio.value ?? 0).rounded()), 43)
        XCTAssertNotNil(report.overall.averageTLPerKWh.value)
        XCTAssertNotNil(report.lastThirtyDays.averageTLPer100Km.value)
        XCTAssertNotNil(report.previousThirtyDayDelta.averageTLPerKWhDelta.value)
    }

    func testAnalyzeMarksTLPer100KmAsEstimatedWhenFactoryFallbackIsUsed() {
        let vehicle = Vehicle(
            brand: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 60,
            factoryConsumptionKWh100km: 14.0
        )
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessions = [
            makeSession(daysAgo: 1, method: .publicDC, price: 390, energy: 30, odometer: nil, startSOC: 20, endSOC: 76, duration: 28),
            makeSession(daysAgo: 8, method: .home, price: 170, energy: 24, odometer: nil, startSOC: 32, endSOC: 80, duration: 210)
        ]

        let report = service.analyze(vehicle: vehicle, sessions: sessions, referenceDate: referenceDate)

        XCTAssertEqual(report.overall.averageTLPer100Km.confidence.source, .estimated)
        XCTAssertNotNil(report.overall.averageTLPer100Km.value)
    }

    func testAnalyzeReturnsUnavailableConfidenceWhenMetricCannotBeComputed() {
        let vehicle = Vehicle(
            brand: "BYD",
            model: "Seal",
            year: 2025,
            batteryCapacityKWh: 82.5
        )
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessions = [
            makeSession(daysAgo: 3, method: .publicDC, price: 250, energy: nil, odometer: nil, startSOC: 0, endSOC: 0, duration: nil)
        ]

        let report = service.analyze(vehicle: vehicle, sessions: sessions, referenceDate: referenceDate)

        XCTAssertNil(report.overall.averageTLPerKWh.value)
        XCTAssertEqual(report.overall.averageTLPerKWh.confidence.source, .unavailable)
        XCTAssertNil(report.overall.averageTLPer100Km.value)
        XCTAssertEqual(report.overall.averageTLPer100Km.confidence.source, .unavailable)
    }

    private func makeSession(
        daysAgo: Int,
        method: ChargeMethod,
        price: Double,
        energy: Double?,
        odometer: Double?,
        startSOC: Double,
        endSOC: Double,
        duration: Int?
    ) -> ChargingSession {
        let referenceDate = Date(timeIntervalSince1970: 1_763_328_000)
        let sessionDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: referenceDate) ?? referenceDate

        return ChargingSession(
            vehicleID: UUID(),
            sessionDate: sessionDate,
            chargeMethod: method,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: startSOC,
            socEnd: endSOC,
            isFullCharge: endSOC >= 99,
            durationMin: duration,
            odometerKM: odometer
        )
    }
}
#endif
