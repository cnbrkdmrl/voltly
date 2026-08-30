#if canImport(XCTest)
import XCTest
@testable import Voltly

final class AnalysisConfidenceServiceTests: XCTestCase {
    private let service = AnalysisConfidenceService()

    func testEvaluateReturnsHighConfidenceForConsistentRichData() {
        let sessions = makeSessions(
            count: 12,
            odometerStart: 10_000,
            odometerStep: 62,
            estimatedEnergyEvery: nil
        )
        let confidence = DataConfidenceScore(
            score: 90,
            source: .real,
            sampleCount: 12,
            exactSampleCount: 12,
            estimatedSampleCount: 0,
            missingSampleCount: 0
        )

        let report = service.evaluate(
            context: .vehicleEfficiency,
            sessions: sessions,
            primaryMetricConfidence: confidence
        )

        XCTAssertEqual(report?.level, .high)
        XCTAssertTrue((report?.score ?? 0) >= 76)
        XCTAssertEqual(report?.realDataPercent, 100)
        XCTAssertNil(report?.secondaryText)
    }

    func testEvaluateReportsEstimatedDataWhenFallbackIsHigh() {
        var sessions = makeSessions(
            count: 10,
            odometerStart: 0,
            odometerStep: 0,
            estimatedEnergyEvery: 1
        )
        sessions = sessions.enumerated().map { index, session in
            var mutable = session
            if index < 6 {
                mutable.odometerKM = nil
            }
            return mutable
        }
        let confidence = DataConfidenceScore(
            score: 52,
            source: .estimated,
            sampleCount: 10,
            exactSampleCount: 0,
            estimatedSampleCount: 10,
            missingSampleCount: 0
        )

        let report = service.evaluate(
            context: .savings,
            sessions: sessions,
            primaryMetricConfidence: confidence
        )

        XCTAssertNotNil(report)
        XCTAssertTrue((report?.fallbackRatio ?? 0) >= 0.25)
        XCTAssertTrue(report?.secondaryText?.contains("tahmini") == true)
        XCTAssertNotEqual(report?.level, .high)
    }

    func testEvaluateIncludesInconsistentRecordSignal() {
        var sessions = makeSessions(
            count: 8,
            odometerStart: 50_000,
            odometerStep: 40,
            estimatedEnergyEvery: nil
        )
        sessions[1].socEnd = 12
        sessions[1].socStart = 28
        sessions[2].durationMin = -5
        sessions[3].socEnd = 14
        sessions[3].socStart = 33
        sessions[4].energyKWh = -2
        sessions[5].priceTotal = -100
        sessions[6].odometerKM = (sessions[5].odometerKM ?? 0) - 300

        let report = service.evaluate(
            context: .chargeHabit,
            sessions: sessions,
            primaryMetricConfidence: nil
        )

        XCTAssertNotNil(report)
        XCTAssertTrue((report?.inconsistentRatio ?? 0) >= 0.4)
        XCTAssertNotNil(report?.secondaryText)
    }

    func testEvaluateReturnsNilWhenSampleCountIsTooLow() {
        let sessions = makeSessions(
            count: 2,
            odometerStart: 12_000,
            odometerStep: 45,
            estimatedEnergyEvery: nil
        )

        let report = service.evaluate(
            context: .chargeHabit,
            sessions: sessions,
            primaryMetricConfidence: nil
        )

        XCTAssertNil(report)
    }

    private func makeSessions(
        count: Int,
        odometerStart: Double,
        odometerStep: Double,
        estimatedEnergyEvery: Int?
    ) -> [ChargingSession] {
        let vehicleID = UUID()

        return (0..<count).map { index in
            let sessionDate = Date(timeIntervalSince1970: 1_763_300_000 + Double(index * 3_600))
            let isEstimated = estimatedEnergyEvery.map { every in
                every > 0 && index % every == 0
            } ?? false
            let odometer = odometerStep > 0
                ? odometerStart + (Double(index) * odometerStep)
                : nil

            return ChargingSession(
                vehicleID: vehicleID,
                sessionDate: sessionDate,
                chargeMethod: index.isMultiple(of: 3) ? .publicDC : .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 280 + Double(index * 8),
                currencyCode: "TRY",
                energyKWh: 21 + Double(index % 5),
                energyIsEstimated: isEstimated,
                socStart: 18,
                socEnd: 78,
                isFullCharge: false,
                durationMin: 42,
                odometerKM: odometer
            )
        }
    }
}
#endif
