#if canImport(XCTest)
import XCTest
@testable import Voltly

final class DetectTrendBreakSkillTests: XCTestCase {
    private let skill = DetectTrendBreakSkill()
    private let service = TrendBreakDetectionService()

    func testDetectReturnsCostIncreaseWhenAverageTLPerKWhJumpsAboveThreshold() {
        let insight = skill.detect(
            input: DetectTrendBreakInput(
                last30Days: [
                    makeSession(day: 1, method: .publicDC, price: 560, energy: 35, odometer: 10_400),
                    makeSession(day: 3, method: .publicAC, price: 450, energy: 30, odometer: 10_200),
                    makeSession(day: 5, method: .home, price: 240, energy: 20, odometer: 10_000)
                ],
                previous30Days: [
                    makeSession(day: 35, method: .publicAC, price: 300, energy: 30, odometer: 9_600),
                    makeSession(day: 40, method: .home, price: 190, energy: 22, odometer: 9_400)
                ]
            )
        )

        XCTAssertEqual(insight?.type, .costIncrease)
        XCTAssertGreaterThanOrEqual(insight?.percentageChange ?? 0, 15)
    }

    func testDetectReturnsDCIncreaseWhenRatioJumpsByTwentyPoints() {
        let insight = skill.detect(
            input: DetectTrendBreakInput(
                last30Days: [
                    makeSession(day: 1, method: .publicDC, price: 300, energy: 30, odometer: 10_400),
                    makeSession(day: 3, method: .publicDC, price: 310, energy: 31, odometer: 10_200),
                    makeSession(day: 5, method: .publicAC, price: 280, energy: 28, odometer: 10_000)
                ],
                previous30Days: [
                    makeSession(day: 35, method: .publicAC, price: 250, energy: 25, odometer: 9_800),
                    makeSession(day: 40, method: .home, price: 220, energy: 22, odometer: 9_600)
                ]
            )
        )

        XCTAssertEqual(insight?.type, .dcIncrease)
        XCTAssertGreaterThanOrEqual(insight?.percentageChange ?? 0, 20)
    }

    func testDetectReturnsNilWhenMinimumSessionCountIsNotMet() {
        let insight = skill.detect(
            input: DetectTrendBreakInput(
                last30Days: [
                    makeSession(day: 1, method: .publicDC, price: 400, energy: 30, odometer: 10_400),
                    makeSession(day: 3, method: .publicAC, price: 220, energy: 24, odometer: 10_200)
                ],
                previous30Days: [
                    makeSession(day: 35, method: .home, price: 160, energy: 22, odometer: 9_800),
                    makeSession(day: 40, method: .home, price: 150, energy: 21, odometer: 9_600)
                ]
            )
        )

        XCTAssertNil(insight)
    }

    func testDetectionServiceFlagsNewExpensiveStation() {
        let result = service.detect(
            input: TrendBreakDetectionInput(
                recentSessions: [
                    makeSession(day: 1, method: .publicDC, price: 480, energy: 24, odometer: 10_500, stationBrand: "YeniNet", locationName: "Bostanci"),
                    makeSession(day: 3, method: .publicDC, price: 520, energy: 25, odometer: 10_350, stationBrand: "YeniNet", locationName: "Bostanci"),
                    makeSession(day: 5, method: .publicAC, price: 210, energy: 25, odometer: 10_150, stationBrand: "ZES", locationName: "Kadikoy")
                ],
                baselineSessions: [
                    makeSession(day: 20, method: .publicAC, price: 210, energy: 24, odometer: 9_850, stationBrand: "ZES", locationName: "Kadikoy"),
                    makeSession(day: 22, method: .home, price: 170, energy: 22, odometer: 9_700, stationBrand: nil, locationName: nil)
                ],
                referenceDate: .now
            )
        )

        XCTAssertTrue(result.insights.contains { $0.type == .expensiveNewStation })
    }

    func testDetectionServiceFlagsEnergyDurationAndRangeShifts() {
        let result = service.detect(
            input: TrendBreakDetectionInput(
                recentSessions: [
                    makeSession(day: 1, method: .publicAC, price: 420, energy: 40, odometer: 10_600, duration: 62, startSOC: 10, endSOC: 92),
                    makeSession(day: 3, method: .publicAC, price: 430, energy: 41, odometer: 10_420, duration: 64, startSOC: 12, endSOC: 90),
                    makeSession(day: 5, method: .publicAC, price: 410, energy: 39, odometer: 10_240, duration: 60, startSOC: 14, endSOC: 88)
                ],
                baselineSessions: [
                    makeSession(day: 20, method: .publicAC, price: 260, energy: 26, odometer: 9_900, duration: 42, startSOC: 22, endSOC: 74),
                    makeSession(day: 22, method: .publicAC, price: 250, energy: 25, odometer: 9_720, duration: 40, startSOC: 24, endSOC: 72),
                    makeSession(day: 24, method: .publicAC, price: 245, energy: 24, odometer: 9_560, duration: 39, startSOC: 26, endSOC: 70)
                ],
                referenceDate: .now
            )
        )

        XCTAssertTrue(result.insights.contains { $0.type == .energyChange || $0.type == .efficiencyDrop })
        XCTAssertTrue(result.insights.contains { $0.type == .durationChange })
        XCTAssertTrue(result.insights.contains { $0.type == .rangeChange })
    }

    private func makeSession(
        day: Int,
        method: ChargeMethod,
        price: Double,
        energy: Double,
        odometer: Double,
        stationBrand: String? = "ZES",
        locationName: String? = "Kadikoy",
        duration: Int = 35,
        startSOC: Double = 20,
        endSOC: Double = 80
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: UUID(),
            sessionDate: Calendar.current.date(byAdding: .day, value: -day, to: .now) ?? .now,
            chargeMethod: method,
            stationBrand: stationBrand,
            locationName: locationName,
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: startSOC,
            socEnd: endSOC,
            isFullCharge: false,
            durationMin: duration,
            odometerKM: odometer
        )
    }
}
#endif
