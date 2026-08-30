#if canImport(XCTest)
import XCTest
@testable import Voltly

#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@MainActor
final class SwiftDataRepositoriesTests: XCTestCase {
    func testVehicleRepositoryCRUDAndActiveSelection() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let repository = SwiftDataVehicleRepository(context: context)

        var vehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2024,
            batteryCapacityKWh: 75
        )

        try repository.upsert(vehicle: vehicle)
        XCTAssertEqual(try repository.fetchVehicles().count, 1)

        try repository.setActiveVehicle(id: vehicle.id)
        XCTAssertEqual(try repository.fetchActiveVehicle()?.id, vehicle.id)

        vehicle.model = "Model Y Long Range"
        try repository.upsert(vehicle: vehicle)
        XCTAssertEqual(try repository.fetchVehicles().first?.model, "Model Y Long Range")

        try repository.delete(vehicleID: vehicle.id)
        XCTAssertEqual(try repository.fetchVehicles().count, 0)
    }

    func testFetchActiveVehicleRepairsBrokenActiveSelectionWhenAnotherVehicleHasSessions() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let sessionRepository = SwiftDataChargingSessionRepository(context: context)

        let emptyActiveVehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2024,
            batteryCapacityKWh: 75,
            isActive: true
        )
        let importedVehicle = Vehicle(
            brand: "BYD",
            model: "Seal",
            year: 2024,
            batteryCapacityKWh: 82.5,
            isActive: false
        )

        try vehicleRepository.upsert(vehicle: emptyActiveVehicle)
        try vehicleRepository.upsert(vehicle: importedVehicle)
        try sessionRepository.save(
            session: ChargingSession(
                vehicleID: importedVehicle.id,
                sessionDate: .now,
                chargeMethod: .publicDC,
                priceTotal: 420,
                energyKWh: 34,
                socStart: 18,
                socEnd: 76
            )
        )

        XCTAssertEqual(try vehicleRepository.fetchActiveVehicle()?.id, importedVehicle.id)
    }
}
#else
final class SwiftDataRepositoriesTests: XCTestCase {
    func testSwiftDataTestsSkippedOutsideiOSBuild() {
        XCTAssertTrue(true)
    }
}
#endif
#endif
