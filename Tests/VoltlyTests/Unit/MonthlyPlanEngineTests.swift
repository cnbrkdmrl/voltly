#if canImport(XCTest)
import XCTest
@testable import Voltly

final class MonthlyPlanEngineTests: XCTestCase {
    private let engine = MonthlyPlanEngine()

    func testBuildPlanCreatesDCReductionAndSpendingActions() {
        let report = makeReport(home: 10, ac: 20, dc: 70)
        let goals = [
            UserGoal(type: .dcUsageRatio, targetValue: 60),
            UserGoal(type: .monthlySpending, targetValue: 2_000)
        ]
        let summary = makeSummary(totalCost: 2_350)

        let plan = engine.buildPlan(
            MonthlyPlanInput(
                usageMode: .balanced,
                suggestedGoals: nil,
                activeGoals: goals,
                report: report,
                savingsSummary: summary,
                sessions: [],
                referenceDate: Date(timeIntervalSince1970: 1_775_200_000)
            ),
            confidence: .medium
        )

        XCTAssertTrue(plan.actions.contains(where: { $0.type == .reduceDC }))
        XCTAssertTrue(plan.actions.contains(where: { $0.type == .reduceCost }))
        XCTAssertEqual(plan.status, .active)
    }

    func testBuildPlanUsesSuggestedGoalsWhenNoActiveGoalsExist() {
        let report = makeReport(home: 5, ac: 10, dc: 85)
        let suggestions = SuggestedGoalSet(
            goals: [
                SuggestedGoal(type: .dcUsageRatio, targetValue: 60, reason: "test", confidence: .medium)
            ],
            title: "title",
            subtitle: "subtitle"
        )

        let plan = engine.buildPlan(
            MonthlyPlanInput(
                usageMode: .savingsFocused,
                suggestedGoals: suggestions,
                activeGoals: [],
                report: report,
                savingsSummary: makeSummary(totalCost: 900),
                sessions: [],
                referenceDate: Date()
            ),
            confidence: .high
        )

        XCTAssertEqual(plan.actions.first(where: { $0.type == .reduceDC })?.targetValue, 60)
    }

    private func makeReport(home: Double, ac: Double, dc: Double) -> ChargeInsightReport {
        ChargeInsightReport(
            generatedAt: .now,
            currencyCode: "TRY",
            overall: makeWindowSummary(),
            lastFiveSessions: makeWindowSummary(),
            lastThirtyDays: makeWindowSummary(),
            previousThirtyDays: makeWindowSummary(),
            previousThirtyDayDelta: ChargeInsightWindowDelta(
                averageStartSOCDelta: .init(value: nil, confidence: .unavailable),
                averageEndSOCDelta: .init(value: nil, confidence: .unavailable),
                averageEnergyKWhDelta: .init(value: nil, confidence: .unavailable),
                averageDurationMinutesDelta: .init(value: nil, confidence: .unavailable),
                averageTLPerKWhDelta: .init(value: nil, confidence: .unavailable),
                averageTLPer100KmDelta: .init(value: nil, confidence: .unavailable)
            ),
            usageRatios: ChargeInsightUsageRatios(
                homeRatio: .init(value: home, confidence: .unavailable),
                acRatio: .init(value: ac, confidence: .unavailable),
                dcRatio: .init(value: dc, confidence: .unavailable)
            ),
            actionInsights: []
        )
    }

    private func makeWindowSummary() -> ChargeInsightWindowSummary {
        .init(
            sessionCount: 6,
            averageStartSOC: .init(value: 20, confidence: .unavailable),
            averageEndSOC: .init(value: 80, confidence: .unavailable),
            averageEnergyKWh: .init(value: 30, confidence: .unavailable),
            averageDurationMinutes: .init(value: 45, confidence: .unavailable),
            averageTLPerKWh: .init(value: 10, confidence: .unavailable),
            averageTLPer100Km: .init(value: 180, confidence: .unavailable)
        )
    }

    private func makeSummary(totalCost: Double) -> SavingsSummary {
        SavingsSummary(
            period: .thisMonth,
            totalEnergyKWh: 100,
            totalEvCost: totalCost,
            estimatedDistanceKm: 500,
            avgConsumptionKWh100km: 20,
            gasolineEquivalentCost: 2_900,
            savingsAmount: 550,
            savingsPercent: 18,
            evCostPer100Km: 180,
            gasolineCostPer100Km: 420,
            costPerKWh: 9,
            sessionCount: 6,
            confidenceLevel: .medium,
            confidenceReport: .init(level: .medium, score: 70, explanation: "test"),
            calculationMode: .init(distance: .odometer, consumption: .realData),
            warnings: [],
            explanationText: "test",
            consumptionLabel: "test",
            debugInfo: nil
        )
    }
}
#endif
