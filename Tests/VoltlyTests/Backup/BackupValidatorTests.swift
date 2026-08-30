#if canImport(XCTest)
import XCTest
@testable import Voltly

final class BackupValidatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_710_000_000)

    func testDecodeAndValidateAcceptsCurrentSchema() throws {
        let archive = makeArchive()
        let data = try JSONBackupBuilder.makeEncoder().encode(archive)

        let validator = BackupValidator(supportedSchemaVersion: AppSchemaVersion.current.rawValue)
        let decoded = try validator.decodeAndValidate(from: data)

        XCTAssertEqual(decoded, archive)
    }

    func testDecodeAndValidateRejectsUnsupportedSchemaVersion() throws {
        let archive = makeArchive(schemaVersion: 99)
        let data = try JSONBackupBuilder.makeEncoder().encode(archive)

        let validator = BackupValidator(supportedSchemaVersion: AppSchemaVersion.current.rawValue)

        XCTAssertThrowsError(try validator.decodeAndValidate(from: data)) { error in
            XCTAssertEqual(
                error as? BackupValidationError,
                .unsupportedSchemaVersion(
                    expected: AppSchemaVersion.current.rawValue,
                    found: 99
                )
            )
        }
    }

    func testDecodeAndValidateRejectsCorruptedJSON() {
        let corrupted = Data("{\"schemaVersion\":1,\"vehicles\":[}".utf8)
        let validator = BackupValidator()

        XCTAssertThrowsError(try validator.decodeAndValidate(from: corrupted)) { error in
            XCTAssertEqual(error as? BackupValidationError, .corruptedJSON)
        }
    }

    func testValidateRejectsEmptyAppVersion() {
        let validator = BackupValidator()
        let archive = makeArchive(appVersion: "   ")

        XCTAssertThrowsError(try validator.validate(archive)) { error in
            XCTAssertEqual(
                error as? BackupValidationError,
                .invalidArchive(reason: "appVersion alani bos olamaz")
            )
        }
    }

    func testDuplicateIdentifierWarningsDetectAllCollections() {
        let duplicateVehicleID = UUID()
        let duplicateSessionID = UUID()
        let duplicateTariffID = UUID()

        let archive = BackupArchiveDTO(
            schemaVersion: AppSchemaVersion.current.rawValue,
            exportedAt: now,
            appVersion: "1.0.0",
            vehicles: [
                makeVehicleDTO(id: duplicateVehicleID, updatedAt: now),
                makeVehicleDTO(id: duplicateVehicleID, updatedAt: now.addingTimeInterval(60))
            ],
            chargingSessions: [
                makeSessionDTO(id: duplicateSessionID, updatedAt: now),
                makeSessionDTO(id: duplicateSessionID, updatedAt: now.addingTimeInterval(60))
            ],
            tariffPresets: [
                makeTariffDTO(id: duplicateTariffID, updatedAt: now),
                makeTariffDTO(id: duplicateTariffID, updatedAt: now.addingTimeInterval(60))
            ],
            userPreferences: makeUserPreferencesDTO()
        )

        let warnings = BackupValidator().duplicateIdentifierWarnings(in: archive)

        XCTAssertEqual(warnings.count, 3)
        XCTAssertTrue(warnings.contains(where: { $0.contains("vehicles") }))
        XCTAssertTrue(warnings.contains(where: { $0.contains("chargingSessions") }))
        XCTAssertTrue(warnings.contains(where: { $0.contains("tariffPresets") }))
    }

    private func makeArchive(
        schemaVersion: Int = AppSchemaVersion.current.rawValue,
        appVersion: String = "1.0.0"
    ) -> BackupArchiveDTO {
        BackupArchiveDTO(
            schemaVersion: schemaVersion,
            exportedAt: now,
            appVersion: appVersion,
            vehicles: [makeVehicleDTO()],
            chargingSessions: [makeSessionDTO()],
            tariffPresets: [makeTariffDTO()],
            userPreferences: makeUserPreferencesDTO()
        )
    }

    private func makeVehicleDTO(
        id: UUID = UUID(),
        updatedAt: Date? = nil
    ) -> VehicleBackupDTO {
        VehicleBackupDTO(
            id: id,
            brand: "Tesla",
            model: "Model Y",
            versionName: "Long Range",
            batteryCapacityKWh: 75,
            createdAt: now,
            updatedAt: updatedAt ?? now,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeSessionDTO(
        id: UUID = UUID(),
        updatedAt: Date? = nil
    ) -> ChargingSessionBackupDTO {
        ChargingSessionBackupDTO(
            id: id,
            vehicleId: UUID(),
            date: now,
            stationName: "ZES Levent",
            operatorName: "ZES",
            chargerType: .ac,
            startSoc: 20,
            endSoc: 80,
            energyKWh: 32,
            durationMinutes: 50,
            totalPrice: 250,
            currencyCode: AppCurrencyCode.turkishLira.rawValue,
            odometerKm: 12_300,
            note: "Not",
            createdAt: now,
            updatedAt: updatedAt ?? now,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeTariffDTO(
        id: UUID = UUID(),
        updatedAt: Date? = nil
    ) -> TariffPresetBackupDTO {
        TariffPresetBackupDTO(
            id: id,
            title: "Ev Tarifesi",
            pricePerKWh: 3.25,
            currencyCode: AppCurrencyCode.turkishLira.rawValue,
            providerName: "CK",
            createdAt: now,
            updatedAt: updatedAt ?? now,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeUserPreferencesDTO() -> UserPreferencesBackupDTO {
        UserPreferencesBackupDTO(
            id: UserPreferencesBackupDTO.defaultIdentifier,
            selectedCurrencyCode: AppCurrencyCode.turkishLira.rawValue,
            distanceUnit: .km,
            energyUnit: .kilowattHour,
            defaultChargerType: .ac,
            includeOdometerInForms: true,
            createdAt: now,
            updatedAt: now,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }
}
#endif
