#if canImport(XCTest)
import XCTest
@testable import Voltly

final class GenerateDailyInsightSkillTests: XCTestCase {
    private let service = DailyInsightService()

    func testGenerateReturnsRisingCostInsightWithHighestPriority() {
        let sessions = [
            makeSession(daysAgo: 0, method: .publicDC, tlPerKWh: 14.5),
            makeSession(daysAgo: 1, method: .publicAC, tlPerKWh: 12.0),
            makeSession(daysAgo: 2, method: .home, tlPerKWh: 9.5)
        ]

        let insight = service.generate(
            input: DailyInsightInput(
                lastSessions: sessions,
                trendData: DailyInsightTrendData(
                    savingsDelta: -120,
                    averageChargeRangeDelta: 16
                ),
                usageStats: DailyInsightUsageStats(
                    currentWeekDCRatio: 70,
                    previousWeekDCRatio: 20
                ),
                stationStats: DailyInsightStationStats(
                    stationName: "ZES • Kadikoy",
                    averageTLPerKWh: 16,
                    overallAverageTLPerKWh: 12,
                    sessionCount: 4
                )
            )
        )

        XCTAssertEqual(insight?.id, "rising-costs")
        XCTAssertEqual(insight?.text, "Son 3 şarjın kademeli olarak pahalanıyor.")
    }

    func testGenerateReturnsExpensivePrimaryStationInsight() {
        let insight = service.generate(
            input: DailyInsightInput(
                lastSessions: [makeSession(daysAgo: 0, method: .home, tlPerKWh: 7.0)],
                trendData: DailyInsightTrendData(savingsDelta: nil),
                usageStats: DailyInsightUsageStats(
                    currentWeekDCRatio: 20,
                    previousWeekDCRatio: 20
                ),
                stationStats: DailyInsightStationStats(
                    stationName: "ZES • Kadikoy",
                    averageTLPerKWh: 14.2,
                    overallAverageTLPerKWh: 12.1,
                    sessionCount: 4
                )
            )
        )

        XCTAssertEqual(insight?.kind, .expensivePrimaryStation)
        XCTAssertEqual(insight?.text, "ZES • Kadikoy ortalamanın üzerinde pahalı kalıyor.")
    }

    func testGenerateReturnsChargeRangeInsightWhenRangeShiftIsMeaningful() {
        let insight = service.generate(
            input: DailyInsightInput(
                lastSessions: [makeSession(daysAgo: 0, method: .home, tlPerKWh: 7.0)],
                trendData: DailyInsightTrendData(
                    savingsDelta: 0,
                    averageChargeRangeDelta: -14
                ),
                usageStats: DailyInsightUsageStats(
                    currentWeekDCRatio: 20,
                    previousWeekDCRatio: 40
                )
            )
        )

        XCTAssertEqual(insight?.kind, .chargeRangeChanged)
    }

    func testGenerateReturnsNilWhenRulesDoNotMatch() {
        let insight = service.generate(
            input: DailyInsightInput(
                lastSessions: [makeSession(daysAgo: 0, method: .home, tlPerKWh: 7.0)],
                trendData: DailyInsightTrendData(
                    savingsDelta: 0,
                    averageChargeRangeDelta: 4
                ),
                usageStats: DailyInsightUsageStats(
                    currentWeekDCRatio: 20,
                    previousWeekDCRatio: 40
                )
            )
        )

        XCTAssertNil(insight)
    }

    private func makeSession(daysAgo: Int, method: ChargeMethod, tlPerKWh: Double) -> ChargingSession {
        let energy = 20.0
        let price = energy * tlPerKWh
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now

        return ChargingSession(
            vehicleID: UUID(),
            sessionDate: date,
            chargeMethod: method,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: price,
            currencyCode: "TRY",
            energyKWh: energy,
            energyIsEstimated: false,
            socStart: 20,
            socEnd: 80,
            isFullCharge: false,
            durationMin: 30,
            odometerKM: 10_000
        )
    }
}
#endif
