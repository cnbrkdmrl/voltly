#if canImport(XCTest)
import XCTest
@testable import Voltly

final class GoalSuggestionEngineTests: XCTestCase {
    private let engine = GoalSuggestionEngine()

    func testSuggestBuildsConservativeInitialGoalsWhenDataIsMissing() {
        let set = engine.suggest(
            input: GoalSuggestionInput(
                usageMode: .balanced,
                report: nil,
                savingsReport: nil,
                sessions: [],
                referenceDate: Date(timeIntervalSince1970: 1_775_200_000)
            )
        )

        XCTAssertEqual(set.goals.count, 3)
        XCTAssertEqual(set.goals.first(where: { $0.type == .monthlyChargeEntries })?.targetValue, 3)
        XCTAssertEqual(set.goals.first(where: { $0.type == .monthlySpending })?.confidence, .low)
    }

    func testSuggestReducesDCTargetForSavingsMode() {
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        let sessions = [
            makeSession(method: .publicDC, daysAgo: 2, price: 500, energy: 34),
            makeSession(method: .publicDC, daysAgo: 5, price: 470, energy: 33),
            makeSession(method: .publicDC, daysAgo: 9, price: 490, energy: 35),
            makeSession(method: .publicAC, daysAgo: 12, price: 230, energy: 28),
            makeSession(method: .home, daysAgo: 15, price: 160, energy: 18)
        ]
        let report = ChargeInsightService().analyze(vehicle: vehicle, sessions: sessions)

        let set = engine.suggest(
            input: GoalSuggestionInput(
                usageMode: .savingsFocused,
                report: report,
                savingsReport: nil,
                sessions: sessions
            )
        )

        XCTAssertEqual(set.goals.first(where: { $0.type == .dcUsageRatio })?.targetValue, 55)
    }

    private func makeSession(
        method: ChargeMethod,
        daysAgo: Int,
        price: Double,
        energy: Double
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: UUID(),
            sessionDate: Date().addingTimeInterval(-Double(daysAgo * 86_400)),
            chargeMethod: method,
            priceTotal: price,
            energyKWh: energy,
            socStart: 20,
            socEnd: 80
        )
    }
}
#endif
