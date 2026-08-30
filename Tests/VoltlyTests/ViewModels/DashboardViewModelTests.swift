#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testLoadsMonthlySnapshot() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let session = ChargingSession(
            vehicleID: vehicle.id,
            sessionDate: .now,
            chargeMethod: .home,
            priceTotal: 360,
            energyKWh: 36,
            socStart: 20,
            socEnd: 70
        )
        try env.logChargingSessionUseCase.execute(session)

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.snapshot.monthlySessionCount, 1)
        XCTAssertEqual(vm.snapshot.monthlyTotalCost, 360, accuracy: 0.01)
        XCTAssertEqual(vm.snapshot.monthlyTotalEnergy, 36, accuracy: 0.01)
    }

    func testLoadFallsBackToLastThirtyDaysWhenCurrentMonthHasNoSession() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let referenceDate = Date(timeIntervalSince1970: 1_775_452_800) // 2026-04-09
        let marchSessionDate = Calendar.current.date(byAdding: .day, value: -10, to: referenceDate) ?? referenceDate

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: marchSessionDate,
                chargeMethod: .home,
                priceTotal: 420,
                energyKWh: 35,
                socStart: 20,
                socEnd: 78
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load(referenceDate: referenceDate)

        XCTAssertEqual(vm.snapshot.primaryPeriodLabel, "Son 30 Gün")
        XCTAssertEqual(vm.snapshot.monthlyTotalCost, 420, accuracy: 0.01)
        XCTAssertEqual(vm.snapshot.monthlySessionCount, 1)
    }

    func testDashboardPrefersRealtimeMetricSnapshotForPerHundredValues() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.vehicleMetricSnapshotRepository.replace(
            vehicleID: vehicle.id,
            snapshots: [
                VehicleMetricSnapshot(
                    vehicleID: vehicle.id,
                    period: .last30Days,
                    avgKWh100Km: 16.4,
                    avgTRY100Km: 132,
                    gasolineTRY100Km: 420,
                    savingTRY100Km: 288,
                    savingPercent: 68.5,
                    basisLabel: ConsumptionBlockConfidenceType.real.basisLabel
                ),
                VehicleMetricSnapshot(
                    vehicleID: vehicle.id,
                    period: .last365Days,
                    avgKWh100Km: 17.1,
                    avgTRY100Km: 140,
                    gasolineTRY100Km: 420,
                    savingTRY100Km: 280,
                    savingPercent: 66.6,
                    basisLabel: ConsumptionBlockConfidenceType.estimated.basisLabel
                )
            ]
        )

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.snapshot.tlPer100Km?.value ?? 0, 132, accuracy: 0.001)
        XCTAssertEqual(vm.snapshot.tlPer100Km?.isEstimated, false)
        XCTAssertEqual(vm.snapshot.averageEnergyPer100Km?.value ?? 0, 17.1, accuracy: 0.001)
        XCTAssertEqual(vm.snapshot.averageEnergyPer100Km?.isEstimated, true)
        XCTAssertEqual(vm.snapshot.calculationExplanation, ConsumptionBlockConfidenceType.real.basisLabel)
    }

    func testLoadPublishesDailyInsightWhenCandidateExists() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now.addingTimeInterval(-2 * 24 * 60 * 60),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 180,
                energyKWh: 20,
                socStart: 20,
                socEnd: 70
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now.addingTimeInterval(-24 * 60 * 60),
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 240,
                energyKWh: 20,
                socStart: 22,
                socEnd: 76
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now,
                chargeMethod: .publicDC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 300,
                energyKWh: 20,
                socStart: 24,
                socEnd: 80
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.dailyInsight?.kind, .risingCosts)
    }

    func testLoadPublishesRetentionPromptWhenLastChargeIsTooOld() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let referenceDate = Date(timeIntervalSince1970: 1_774_699_200) // 2026-03-23
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: referenceDate.addingTimeInterval(-9 * 24 * 60 * 60),
                chargeMethod: .publicAC,
                stationBrand: "ZES",
                locationName: "Kadikoy",
                priceTotal: 260,
                energyKWh: 22,
                socStart: 20,
                socEnd: 76
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load(referenceDate: referenceDate)

        XCTAssertEqual(vm.retentionPrompt?.type, .missingRecentEntry)
        XCTAssertEqual(vm.retentionPrompt?.daysSinceLastSession, 9)
    }

    func testTrendIncludesPastMonths() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let calendar = Calendar.current
        let now = Date()
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: previousMonthDate,
                chargeMethod: .home,
                priceTotal: 250,
                energyKWh: 25,
                socStart: 20,
                socEnd: 70
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now,
                chargeMethod: .publicAC,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 30,
                socEnd: 80
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.snapshot.trend.count, 2)
        XCTAssertEqual(try XCTUnwrap(vm.snapshot.trend.last?.spend), 300, accuracy: 0.01)
    }

    func testDashboardUsesFactoryConsumptionForShortHistoricalDistanceBlock() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 18
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: lastMonth,
                chargeMethod: .home,
                priceTotal: 250,
                energyKWh: 20,
                socStart: 20,
                socEnd: 60,
                odometerKM: 15_000
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now,
                chargeMethod: .publicAC,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 30,
                socEnd: 80,
                odometerKM: 15_200
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.snapshot.averageEnergyPer100Km?.value ?? 0, 18, accuracy: 0.01)
        XCTAssertEqual(vm.snapshot.averageEnergyPer100Km?.isEstimated, true)
    }

    func testDashboardComputesTotalSavingsAgainstGasoline() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2025,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: 20
        )
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now.addingTimeInterval(-3_600),
                chargeMethod: .home,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 20,
                socEnd: 70
            )
        )

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: .now,
                chargeMethod: .publicAC,
                priceTotal: 200,
                energyKWh: 20,
                socStart: 30,
                socEnd: 65
            )
        )

        let vm = DashboardViewModel(environment: env)
        vm.load()

        XCTAssertEqual(vm.snapshot.totalSavingsAmount ?? 0, 740, accuracy: 0.01)
        XCTAssertEqual(vm.snapshot.totalSavingsPercent ?? 0, 59.68, accuracy: 0.1)
    }
}
#endif
