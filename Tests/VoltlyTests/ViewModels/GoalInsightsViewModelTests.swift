#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class GoalInsightsViewModelTests: XCTestCase {
    func testLoadBuildsGoalProgressSnapshot() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 17.7
        )

        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)
        try env.goalRepository.saveGoals([
            UserGoal(type: .monthlySpending, targetValue: 1_500),
            UserGoal(type: .dcUsageRatio, targetValue: 40)
        ])

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now,
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 420,
                currencyCode: "TRY",
                energyKWh: 35,
                energyIsEstimated: false,
                socStart: 18,
                socEnd: 78,
                durationMin: 36,
                odometerKM: 14_200
            )
        )

        let viewModel = InsightsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.goalProgressSnapshot?.items.count, 2)
        XCTAssertTrue(viewModel.goalProgressSnapshot?.items.contains { $0.type == .monthlySpending } == true)
    }
}
#endif
