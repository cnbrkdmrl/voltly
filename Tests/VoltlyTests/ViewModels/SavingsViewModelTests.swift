#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class SavingsViewModelTests: XCTestCase {
    func testLoadKeepsOnlyMonthlySavingsShareVariant() throws {
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
            UserGoal(type: .dcUsageRatio, targetValue: 60)
        ])

        let sessions = [
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now.addingTimeInterval(-7_200),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 440,
                energyKWh: 28,
                socStart: 18,
                socEnd: 84
            ),
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now.addingTimeInterval(-3_600),
                chargeMethod: .publicAC,
                stationBrand: "Trugo",
                locationName: "Levent",
                priceTotal: 210,
                energyKWh: 22,
                socStart: 22,
                socEnd: 74
            )
        ]

        for session in sessions {
            try env.logChargingSessionUseCase.execute(session)
        }

        let viewModel = SavingsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.availableShareVariants, [.monthlySavings])
        XCTAssertEqual(viewModel.selectedShareVariant, .monthlySavings)
    }

    func testLoadFallsBackToLastThirtyDaysWhenCurrentMonthIsEmpty() throws {
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

        let referenceDate = Date(timeIntervalSince1970: 1_775_452_800) // 2026-04-09
        let marchSessionDate = Date(timeIntervalSince1970: 1_773_964_800) // 2026-03-23

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: marchSessionDate,
                chargeMethod: .publicAC,
                priceTotal: 360,
                energyKWh: 28,
                socStart: 22,
                socEnd: 72
            )
        )

        let viewModel = SavingsViewModel(environment: env)
        viewModel.load(referenceDate: referenceDate)

        XCTAssertEqual(viewModel.primaryPeriodTitle, "Son 30 gün")
        XCTAssertEqual(viewModel.monthlyEVSpendTL, 360, accuracy: 0.001)
        XCTAssertEqual(viewModel.monthlySessionCount, 1)
        XCTAssertEqual(viewModel.shareCardContent.badgeTitle, "Son 30 Gün Tasarruf")
    }

    func testSelectingUnsupportedShareVariantFallsBackToMonthlySavings() throws {
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

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now,
                chargeMethod: .home,
                priceTotal: 180,
                energyKWh: 20,
                socStart: 24,
                socEnd: 68
            )
        )

        let viewModel = SavingsViewModel(environment: env)
        viewModel.load(referenceDate: .now)
        viewModel.selectShareVariant(.carbonGain)

        XCTAssertEqual(viewModel.selectedShareVariant, .monthlySavings)
        XCTAssertEqual(viewModel.shareCardContent.variant, .monthlySavings)
        XCTAssertFalse(viewModel.shareCopy.isEmpty)
    }

    func testLoadPrefersRealtimeSnapshotForPerHundredDisplay() throws {
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
        try env.vehicleMetricSnapshotRepository.replace(
            vehicleID: vehicle.id,
            snapshots: [
                VehicleMetricSnapshot(
                    vehicleID: vehicle.id,
                    period: .last30Days,
                    avgKWh100Km: 16.8,
                    avgTRY100Km: 129,
                    gasolineTRY100Km: 410,
                    savingTRY100Km: 281,
                    savingPercent: 68.5,
                    basisLabel: ConsumptionBlockConfidenceType.real.basisLabel
                )
            ]
        )

        let viewModel = SavingsViewModel(environment: env)
        viewModel.load(referenceDate: .now)

        XCTAssertEqual(viewModel.tlPer100Km?.value ?? 0, 129, accuracy: 0.001)
        XCTAssertEqual(viewModel.tlPer100Km?.isEstimated, false)
        XCTAssertEqual(viewModel.gasolineSavingsPercent ?? 0, 68.5, accuracy: 0.001)
        XCTAssertEqual(viewModel.calculationExplanation, ConsumptionBlockConfidenceType.real.basisLabel)
    }
}
#endif
