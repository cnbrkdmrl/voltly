#if canImport(XCTest)
import XCTest
@testable import Voltly

final class UserChargingProfileServiceTests: XCTestCase {
    private let service = UserChargingProfileService()

    func testMakeProfileReturnsSpeedFocusedWhenDCRatioIsHighAndSessionsAreFast() {
        let report = makeReport(
            sessionCount: 12,
            homeRatio: 10,
            acRatio: 15,
            dcRatio: 75,
            averageDurationMinutes: 42
        )

        let profile = service.makeProfile(report: report)

        XCTAssertEqual(profile?.type, .speedFocused)
        XCTAssertTrue(profile?.description.contains("DC kullanımın yüksek") == true)
        XCTAssertEqual(profile?.ratioSummary, "Ev %10 • AC %15 • DC %75")
    }

    func testMakeProfileReturnsSavingsFocusedWhenHomeAndACDominates() {
        let report = makeReport(
            sessionCount: 14,
            homeRatio: 46,
            acRatio: 35,
            dcRatio: 19,
            averageDurationMinutes: 70
        )

        let profile = service.makeProfile(report: report)

        XCTAssertEqual(profile?.type, .savingsFocused)
        XCTAssertTrue(profile?.description.contains("AC ve ev şarjı ağırlığın") == true)
    }

    func testMakeProfileReturnsDengeliForBalancedDistribution() {
        let report = makeReport(
            sessionCount: 10,
            homeRatio: 30,
            acRatio: 35,
            dcRatio: 35,
            averageDurationMinutes: 62
        )

        let profile = service.makeProfile(report: report)

        XCTAssertEqual(profile?.type, .balanced)
    }

    func testMakeProfileReturnsNilWhenSessionCountIsInsufficient() {
        let report = makeReport(
            sessionCount: 5,
            homeRatio: 33,
            acRatio: 34,
            dcRatio: 33,
            averageDurationMinutes: 58
        )

        XCTAssertNil(service.makeProfile(report: report))
    }

    private func makeReport(
        sessionCount: Int,
        homeRatio: Double,
        acRatio: Double,
        dcRatio: Double,
        averageDurationMinutes: Double
    ) -> ChargeInsightReport {
        let confidence = DataConfidenceScore(
            score: 90,
            source: .real,
            sampleCount: sessionCount,
            exactSampleCount: sessionCount,
            estimatedSampleCount: 0,
            missingSampleCount: 0
        )

        let usageRatios = ChargeInsightUsageRatios(
            homeRatio: InsightMetric(value: homeRatio, confidence: confidence),
            acRatio: InsightMetric(value: acRatio, confidence: confidence),
            dcRatio: InsightMetric(value: dcRatio, confidence: confidence)
        )

        let summary = ChargeInsightWindowSummary(
            sessionCount: sessionCount,
            averageStartSOC: InsightMetric(value: 22, confidence: confidence),
            averageEndSOC: InsightMetric(value: 80, confidence: confidence),
            averageEnergyKWh: InsightMetric(value: 28, confidence: confidence),
            averageDurationMinutes: InsightMetric(value: averageDurationMinutes, confidence: confidence),
            averageTLPerKWh: InsightMetric(value: 11.4, confidence: confidence),
            averageTLPer100Km: InsightMetric(value: 210, confidence: confidence)
        )

        let delta = ChargeInsightWindowDelta(
            averageStartSOCDelta: InsightMetric(value: 0, confidence: confidence),
            averageEndSOCDelta: InsightMetric(value: 0, confidence: confidence),
            averageEnergyKWhDelta: InsightMetric(value: 0, confidence: confidence),
            averageDurationMinutesDelta: InsightMetric(value: 0, confidence: confidence),
            averageTLPerKWhDelta: InsightMetric(value: 0, confidence: confidence),
            averageTLPer100KmDelta: InsightMetric(value: 0, confidence: confidence)
        )

        return ChargeInsightReport(
            generatedAt: Date(timeIntervalSince1970: 1_763_328_000),
            currencyCode: "TRY",
            overall: summary,
            lastFiveSessions: summary,
            lastThirtyDays: summary,
            previousThirtyDays: summary,
            previousThirtyDayDelta: delta,
            usageRatios: usageRatios,
            actionInsights: []
        )
    }
}
#endif
