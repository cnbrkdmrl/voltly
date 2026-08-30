#if canImport(XCTest)
import XCTest
@testable import Voltly

#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@MainActor
final class ImportServiceTests: XCTestCase {
    func testImportRestoresFuelBaselineSettingsFromArchive() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let settingsRepository = SwiftDataSettingsRepository(context: context)
        let importService = ImportService(context: context)

        let archiveURL = try makeArchiveFile(
            vehicles: [],
            chargingSessions: [],
            userPreferences: UserPreferencesBackupDTO(
                id: UserPreferencesBackupDTO.defaultIdentifier,
                selectedCurrencyCode: "TRY",
                fuelPricePerLiter: 51.9,
                iceConsumptionLPer100Km: 7.4,
                electricityPricePerKWh: 6.8,
                distanceUnit: .km,
                energyUnit: .kilowattHour,
                defaultChargerType: .ac,
                includeOdometerInForms: true,
                createdAt: .now,
                updatedAt: .now,
                schemaVersion: AppSchemaVersion.current.rawValue,
                isDeleted: false
            )
        )
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        _ = try importService.importArchive(from: archiveURL)

        let baseline = try settingsRepository.getFuelBaseline()
        XCTAssertEqual(baseline.currencyCode, "TRY")
        XCTAssertEqual(baseline.fuelPricePerLiter, 51.9)
        XCTAssertEqual(baseline.iceConsumptionLPer100Km, 7.4)
        XCTAssertEqual(baseline.electricityPricePerKWh, 6.8)
    }

    func testImportEnrichesLegacyVehicleFromReferenceCatalog() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let importService = ImportService(context: context)

        let importedVehicleID = UUID()
        let archiveURL = try makeArchiveFile(
            vehicles: [
                VehicleBackupDTO(
                    id: importedVehicleID,
                    brand: "Opel",
                    model: "Grandland Electric",
                    versionName: nil,
                    year: 2026,
                    batteryCapacityKWh: 73,
                    createdAt: .now.addingTimeInterval(-1_000),
                    updatedAt: .now,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ],
            chargingSessions: []
        )
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        _ = try importService.importArchive(from: archiveURL)

        let importedVehicle = try XCTUnwrap(try vehicleRepository.fetchActiveVehicle())
        XCTAssertEqual(importedVehicle.id, importedVehicleID)
        XCTAssertEqual(importedVehicle.factoryConsumptionKWh100km, 17.7)
        XCTAssertEqual(importedVehicle.dcMaxChargingKW, 160)
        XCTAssertEqual(importedVehicle.silhouetteKey, "opel_grandland_2025")
    }

    func testImportSelectsImportedVehicleWhenCurrentActiveVehicleHasNoSessions() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let sessionRepository = SwiftDataChargingSessionRepository(context: context)
        let importService = ImportService(context: context)

        let localVehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2024,
            batteryCapacityKWh: 75,
            isActive: true
        )
        try vehicleRepository.upsert(vehicle: localVehicle)

        let importedVehicleID = UUID()
        let archiveURL = try makeArchiveFile(
            vehicles: [
                VehicleBackupDTO(
                    id: importedVehicleID,
                    brand: "BYD",
                    model: "Seal",
                    versionName: nil,
                    batteryCapacityKWh: 82.5,
                    createdAt: .now.addingTimeInterval(-1_000),
                    updatedAt: .now,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ],
            chargingSessions: [
                ChargingSessionBackupDTO(
                    id: UUID(),
                    vehicleId: importedVehicleID,
                    date: .now,
                    stationName: "Kadikoy",
                    operatorName: "ZES",
                    chargerType: .ac,
                    startSoc: 20,
                    endSoc: 80,
                    energyKWh: 32,
                    durationMinutes: 90,
                    totalPrice: 410,
                    currencyCode: "TRY",
                    odometerKm: 12_500,
                    note: nil,
                    createdAt: .now.addingTimeInterval(-900),
                    updatedAt: .now,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        _ = try importService.importArchive(from: archiveURL)

        XCTAssertEqual(try vehicleRepository.fetchActiveVehicle()?.id, importedVehicleID)
        XCTAssertEqual(try sessionRepository.fetchAll(vehicleID: importedVehicleID).count, 1)
    }

    func testImportKeepsCurrentActiveVehicleWhenItAlreadyHasSessions() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)
        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let sessionRepository = SwiftDataChargingSessionRepository(context: context)
        let importService = ImportService(context: context)

        let localVehicle = Vehicle(
            brand: "Tesla",
            model: "Model 3",
            year: 2024,
            batteryCapacityKWh: 60,
            isActive: true
        )
        try vehicleRepository.upsert(vehicle: localVehicle)
        try sessionRepository.save(
            session: ChargingSession(
                vehicleID: localVehicle.id,
                sessionDate: .now.addingTimeInterval(-86_400),
                chargeMethod: .home,
                priceTotal: 250,
                energyKWh: 25,
                socStart: 30,
                socEnd: 70
            )
        )

        let importedVehicleID = UUID()
        let archiveURL = try makeArchiveFile(
            vehicles: [
                VehicleBackupDTO(
                    id: importedVehicleID,
                    brand: "BYD",
                    model: "Seal",
                    versionName: nil,
                    batteryCapacityKWh: 82.5,
                    createdAt: .now.addingTimeInterval(-1_000),
                    updatedAt: .now,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ],
            chargingSessions: [
                ChargingSessionBackupDTO(
                    id: UUID(),
                    vehicleId: importedVehicleID,
                    date: .now,
                    stationName: "Besiktas",
                    operatorName: "ZES",
                    chargerType: .dc,
                    startSoc: 15,
                    endSoc: 75,
                    energyKWh: 40,
                    durationMinutes: 50,
                    totalPrice: 520,
                    currencyCode: "TRY",
                    odometerKm: 8_100,
                    note: nil,
                    createdAt: .now.addingTimeInterval(-900),
                    updatedAt: .now,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        _ = try importService.importArchive(from: archiveURL)

        XCTAssertEqual(try vehicleRepository.fetchActiveVehicle()?.id, localVehicle.id)
    }

    private func makeArchiveFile(
        vehicles: [VehicleBackupDTO],
        chargingSessions: [ChargingSessionBackupDTO],
        userPreferences: UserPreferencesBackupDTO = .default()
    ) throws -> URL {
        let archive = BackupArchiveDTO(
            schemaVersion: AppSchemaVersion.current.rawValue,
            exportedAt: .now,
            appVersion: "1.0",
            vehicles: vehicles,
            chargingSessions: chargingSessions,
            tariffPresets: [],
            userPreferences: userPreferences
        )
        let data = try JSONBackupBuilder().encode(archive)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voltly-import-\(UUID().uuidString).json")
        try data.write(to: url)
        return url
    }
}
#else
final class ImportServiceTests: XCTestCase {
    func testImportServiceTestsSkippedOutsideiOSBuild() {
        XCTAssertTrue(true)
    }
}
#endif
#endif
