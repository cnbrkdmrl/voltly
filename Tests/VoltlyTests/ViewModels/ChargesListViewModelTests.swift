#if canImport(XCTest)
import XCTest
@testable import Voltly

@MainActor
final class ChargesListViewModelTests: XCTestCase {
    func testDateFiltersMonthAndYear() throws {
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

        let now = Date()
        let calendar = Calendar.current
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now,
                chargeMethod: .home,
                priceTotal: 300,
                energyKWh: 30,
                socStart: 20,
                socEnd: 80
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: twoMonthsAgo,
                chargeMethod: .publicAC,
                priceTotal: 250,
                energyKWh: 25,
                socStart: 15,
                socEnd: 70
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: lastYear,
                chargeMethod: .publicDC,
                priceTotal: 400,
                energyKWh: 32,
                socStart: 35,
                socEnd: 90
            )
        )

        let vm = ChargesListViewModel(environment: env)

        vm.selectedDateFilter = .month
        vm.load()
        XCTAssertEqual(vm.sessions.count, 1)

        vm.selectedDateFilter = .year
        vm.load()
        XCTAssertEqual(vm.sessions.count, 2)
    }

    func testCombinesMethodAndDateFilters() throws {
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

        let now = Date()
        let calendar = Calendar.current
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now) ?? now

        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now,
                chargeMethod: .publicAC,
                priceTotal: 280,
                energyKWh: 20,
                socStart: 25,
                socEnd: 75
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: twoMonthsAgo,
                chargeMethod: .publicAC,
                priceTotal: 310,
                energyKWh: 23,
                socStart: 30,
                socEnd: 80
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now,
                chargeMethod: .home,
                priceTotal: 200,
                energyKWh: 18,
                socStart: 20,
                socEnd: 70
            )
        )

        let vm = ChargesListViewModel(environment: env)
        vm.selectedMethod = .publicAC
        vm.selectedDateFilter = .month
        vm.load()

        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.sessions.first?.chargeMethod, .publicAC)
        XCTAssertTrue(Calendar.current.isDate(vm.sessions.first?.sessionDate ?? .distantPast, equalTo: now, toGranularity: .month))
    }

    func testSortOptionsApplyCorrectly() throws {
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

        let now = Date()
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now.addingTimeInterval(-300),
                chargeMethod: .home,
                priceTotal: 200,
                energyKWh: 15,
                socStart: 20,
                socEnd: 60
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now.addingTimeInterval(-100),
                chargeMethod: .publicAC,
                priceTotal: 420,
                energyKWh: 32,
                socStart: 25,
                socEnd: 80
            )
        )
        try env.logChargingSessionUseCase.execute(
            ChargingSession(
                vehicleID: vehicle.id,
                sessionDate: now.addingTimeInterval(-200),
                chargeMethod: .publicDC,
                priceTotal: 150,
                energyKWh: 10,
                socStart: 30,
                socEnd: 70
            )
        )

        let vm = ChargesListViewModel(environment: env)

        vm.selectedSort = .mostExpensive
        vm.load()
        XCTAssertEqual(try XCTUnwrap(vm.sessions.first).priceTotal, 420, accuracy: 0.01)

        vm.selectedSort = .cheapest
        vm.load()
        XCTAssertEqual(try XCTUnwrap(vm.sessions.first).priceTotal, 150, accuracy: 0.01)

        vm.selectedSort = .highestEnergy
        vm.load()
        XCTAssertEqual(vm.sessions.first?.energyKWh ?? 0, 32, accuracy: 0.01)
    }

    func testDeleteUpdatesLocalStateWithoutReload() throws {
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

        let first = ChargingSession(
            vehicleID: vehicle.id,
            sessionDate: .now.addingTimeInterval(-3_600),
            chargeMethod: .publicAC,
            priceTotal: 220,
            energyKWh: 20,
            socStart: 20,
            socEnd: 60,
            odometerKM: 10_000
        )
        let second = ChargingSession(
            vehicleID: vehicle.id,
            sessionDate: .now,
            chargeMethod: .publicAC,
            priceTotal: 330,
            energyKWh: 30,
            socStart: 22,
            socEnd: 72,
            odometerKM: 11_050
        )

        try env.logChargingSessionUseCase.execute(first)
        try env.logChargingSessionUseCase.execute(second)

        let vm = ChargesListViewModel(environment: env)
        vm.load()
        XCTAssertEqual(vm.sessions.count, 2)

        vm.delete(second)

        XCTAssertEqual(vm.sessions.count, 1)
        XCTAssertEqual(vm.allSessionCount, 1)
        XCTAssertEqual(vm.sessions.first?.id, first.id)
        XCTAssertEqual(vm.latestRealtimeMetricsUpdate?.latestBlock?.confidenceType, .factory)
    }
}
#endif
