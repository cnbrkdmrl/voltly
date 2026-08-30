import XCTest
@testable import Voltly

@MainActor
final class RealtimeMetricsServicesTests: XCTestCase {
    func testNewRecordCreatesRealBlockWhenNearestCandidateExceedsOneThousandKilometers() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 17.7)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 1_000, energy: 24, cost: 240)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 2_050, energy: 36, cost: 360)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .real)
        XCTAssertEqual(update?.latestBlock?.startRecordID != nil, true)
        XCTAssertEqual(update?.latestBlock?.kWhPer100Km ?? 0, 60 / 1050 * 100, accuracy: 0.001)
    }

    func testNewRecordCreatesEstimatedBlockWhenNearestCandidateIsAboveFiveHundredKilometers() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 17.7)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 2_000, energy: 20, cost: 220)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 2_650, energy: 24, cost: 300)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .estimated)
        XCTAssertEqual(update?.latestBlock?.kWhPer100Km ?? 0, 44 / 650 * 100, accuracy: 0.001)
    }

    func testFactoryFallbackUsedWhenNoFiveHundredKilometerBlockExists() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 18.2)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 10_000, energy: 18, cost: 200)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 10_380, energy: 20, cost: 240)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .factory)
        XCTAssertEqual(update?.latestBlock?.kWhPer100Km, 18.2)
    }

    func testMissingKilometersAreSkippedAndFactoryFallbackIsUsed() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 17.4)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: nil, energy: 22, cost: 210)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 8_200, energy: 26, cost: 280)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .factory)
    }

    func testReverseKilometersAreRejected() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 16.9)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 3_000, energy: 24, cost: 240)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 2_200, energy: 28, cost: 320)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .factory)
    }

    func testOutlierConsumptionFallsBackToFactory() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 17.7)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 1_000, energy: 10, cost: 120)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 2_050, energy: 10, cost: 120)
        )

        XCTAssertEqual(update?.latestBlock?.confidenceType, .factory)
        XCTAssertEqual(update?.latestBlock?.kWhPer100Km, 17.7)
    }

    func testNewRecordUpdatesSnapshotsAndInvalidatesDashboardCache() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 18.0)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        _ = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 5_000, energy: 24, cost: 240)
        )
        let update = try env.logChargingSessionUseCase.execute(
            makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 6_100, energy: 36, cost: 420)
        )

        let snapshot = try env.vehicleMetricSnapshotRepository.fetch(
            vehicleID: vehicle.id,
            period: .allTime
        )

        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.avgKWh100Km ?? 0, 60 / 1100 * 100, accuracy: 0.001)
        XCTAssertEqual(snapshot?.avgTRY100Km ?? 0, 660 / 1100 * 100, accuracy: 0.001)
        XCTAssertTrue(update?.invalidatedDashboard == true)
        XCTAssertNotNil(try env.dashboardCacheService.fetch(vehicleID: vehicle.id))
    }

    func testUpdatingOldRecordRebuildsOnlyAffectedTailRange() throws {
        let env = try AppEnvironment.live(inMemory: true)
        let vehicle = makeVehicle(factoryConsumption: 18.0)
        try env.createVehicleUseCase.execute(vehicle)
        try env.setActiveVehicleUseCase.execute(id: vehicle.id)

        let first = makeSession(vehicleID: vehicle.id, dateOffset: -4_000, odometer: 1_000, energy: 20, cost: 200)
        let second = makeSession(vehicleID: vehicle.id, dateOffset: -3_000, odometer: 1_600, energy: 18, cost: 180)
        let third = makeSession(vehicleID: vehicle.id, dateOffset: -2_000, odometer: 2_250, energy: 24, cost: 260)
        let fourth = makeSession(vehicleID: vehicle.id, dateOffset: -1_000, odometer: 3_350, energy: 36, cost: 420)

        _ = try env.logChargingSessionUseCase.execute(first)
        _ = try env.logChargingSessionUseCase.execute(second)
        _ = try env.logChargingSessionUseCase.execute(third)
        _ = try env.logChargingSessionUseCase.execute(fourth)

        let initialBlocks = try env.consumptionBlockRepository.fetchActive(vehicleID: vehicle.id)
        XCTAssertFalse(initialBlocks.isEmpty)

        var updatedThird = third
        updatedThird.priceTotal = 320
        let update = try env.logChargingSessionUseCase.execute(updatedThird)
        let rebuiltBlocks = try env.consumptionBlockRepository.fetchActive(vehicleID: vehicle.id)

        XCTAssertEqual(rebuiltBlocks.first?.startRecordID, initialBlocks.first?.startRecordID)
        XCTAssertEqual(rebuiltBlocks.last?.endRecordID, fourth.id)
        XCTAssertEqual(update?.latestBlock?.endRecordID, fourth.id)
        XCTAssertTrue((rebuiltBlocks.last?.totalCostTRY ?? 0) >= 320)
    }

    private func makeVehicle(factoryConsumption: Double) -> Vehicle {
        Vehicle(
            brand: "Opel",
            model: "Grandland Electric",
            year: 2026,
            batteryCapacityKWh: 73,
            factoryConsumptionKWh100km: factoryConsumption
        )
    }

    private func makeSession(
        vehicleID: UUID,
        dateOffset: TimeInterval,
        odometer: Double?,
        energy: Double,
        cost: Double
    ) -> ChargingSession {
        ChargingSession(
            vehicleID: vehicleID,
            sessionDate: Date(timeIntervalSinceNow: dateOffset),
            chargeMethod: .publicAC,
            stationBrand: "ZES",
            locationName: "Kadikoy",
            priceTotal: cost,
            energyKWh: energy,
            socStart: 20,
            socEnd: 80,
            odometerKM: odometer
        )
    }
}
