#if canImport(XCTest)
import XCTest
@testable import Voltly

final class RecommendationEngineTests: XCTestCase {
    private let engine = RecommendationEngine()

    func testBuildRecommendationsPrioritizesReduceDC() {
        let items = engine.buildRecommendations(
            RecommendationInput(
                usageMode: .balanced,
                report: makeReport(home: 10, ac: 10, dc: 80),
                savingsSummary: nil,
                suggestedGoals: nil,
                activeGoals: []
            )
        )

        XCTAssertEqual(items.first?.id, "rec.reduce_dc")
        XCTAssertEqual(items.first?.ctaType, .addCharge)
        XCTAssertEqual(items.first?.suggestedChargeType, .publicAC)
    }

    func testBuildRecommendationsFallsBackToFirstGoalPrompt() {
        let items = engine.buildRecommendations(
            RecommendationInput(
                usageMode: .balanced,
                report: nil,
                savingsSummary: nil,
                suggestedGoals: nil,
                activeGoals: []
            )
        )

        XCTAssertEqual(items.first?.id, "rec.first_goal")
    }

    private func makeReport(home: Double, ac: Double, dc: Double) -> ChargeInsightReport {
        ChargeInsightReport(
            generatedAt: .now,
            currencyCode: "TRY",
            overall: .init(
                sessionCount: 8,
                averageStartSOC: .init(value: 20, confidence: .unavailable),
                averageEndSOC: .init(value: 80, confidence: .unavailable),
                averageEnergyKWh: .init(value: 30, confidence: .unavailable),
                averageDurationMinutes: .init(value: 40, confidence: .unavailable),
                averageTLPerKWh: .init(value: 11, confidence: .unavailable),
                averageTLPer100Km: .init(value: 190, confidence: .unavailable)
            ),
            lastFiveSessions: .init(
                sessionCount: 5,
                averageStartSOC: .init(value: 20, confidence: .unavailable),
                averageEndSOC: .init(value: 80, confidence: .unavailable),
                averageEnergyKWh: .init(value: 30, confidence: .unavailable),
                averageDurationMinutes: .init(value: 40, confidence: .unavailable),
                averageTLPerKWh: .init(value: 11, confidence: .unavailable),
                averageTLPer100Km: .init(value: 190, confidence: .unavailable)
            ),
            lastThirtyDays: .init(
                sessionCount: 8,
                averageStartSOC: .init(value: 20, confidence: .unavailable),
                averageEndSOC: .init(value: 80, confidence: .unavailable),
                averageEnergyKWh: .init(value: 30, confidence: .unavailable),
                averageDurationMinutes: .init(value: 40, confidence: .unavailable),
                averageTLPerKWh: .init(value: 11, confidence: .unavailable),
                averageTLPer100Km: .init(value: 190, confidence: .unavailable)
            ),
            previousThirtyDays: .init(
                sessionCount: 8,
                averageStartSOC: .init(value: 20, confidence: .unavailable),
                averageEndSOC: .init(value: 80, confidence: .unavailable),
                averageEnergyKWh: .init(value: 30, confidence: .unavailable),
                averageDurationMinutes: .init(value: 40, confidence: .unavailable),
                averageTLPerKWh: .init(value: 11, confidence: .unavailable),
                averageTLPer100Km: .init(value: 190, confidence: .unavailable)
            ),
            previousThirtyDayDelta: .init(
                averageStartSOCDelta: .init(value: nil, confidence: .unavailable),
                averageEndSOCDelta: .init(value: nil, confidence: .unavailable),
                averageEnergyKWhDelta: .init(value: nil, confidence: .unavailable),
                averageDurationMinutesDelta: .init(value: nil, confidence: .unavailable),
                averageTLPerKWhDelta: .init(value: nil, confidence: .unavailable),
                averageTLPer100KmDelta: .init(value: nil, confidence: .unavailable)
            ),
            usageRatios: .init(
                homeRatio: .init(value: home, confidence: .unavailable),
                acRatio: .init(value: ac, confidence: .unavailable),
                dcRatio: .init(value: dc, confidence: .unavailable)
            ),
            actionInsights: []
        )
    }
}
#endif
