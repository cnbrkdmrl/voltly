#if canImport(XCTest)
import XCTest
@testable import Voltly

final class JSONBackupBuilderTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_720_000_000)

    func testMakeArchiveUsesInjectedDateAndAppVersion() {
        let builder = JSONBackupBuilder(
            appVersionProvider: { "1.2.3 (45)" },
            dateProvider: { self.fixedDate }
        )

        let archive = builder.makeArchive(
            vehicles: [makeVehicleDTO()],
            chargingSessions: [makeSessionDTO()],
            tariffPresets: [makeTariffDTO()],
            userPreferences: makeUserPreferencesDTO()
        )

        XCTAssertEqual(archive.schemaVersion, AppSchemaVersion.current.rawValue)
        XCTAssertEqual(archive.exportedAt, fixedDate)
        XCTAssertEqual(archive.appVersion, "1.2.3 (45)")
    }

    func testMakeArchiveSortsRecordsByUUIDForStableOutput() {
        let builder = JSONBackupBuilder(
            appVersionProvider: { "1.0.0" },
            dateProvider: { self.fixedDate }
        )

        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let archive = builder.makeArchive(
            vehicles: [makeVehicleDTO(id: a), makeVehicleDTO(id: b)],
            chargingSessions: [makeSessionDTO(id: a), makeSessionDTO(id: b)],
            tariffPresets: [makeTariffDTO(id: a), makeTariffDTO(id: b)],
            userPreferences: makeUserPreferencesDTO()
        )

        XCTAssertEqual(archive.vehicles.map(\.id), [b, a])
        XCTAssertEqual(archive.chargingSessions.map(\.id), [b, a])
        XCTAssertEqual(archive.tariffPresets.map(\.id), [b, a])
    }

    func testEncodeAndDecodeRoundTrip() throws {
        let builder = JSONBackupBuilder(
            appVersionProvider: { "1.0.1" },
            dateProvider: { self.fixedDate }
        )

        let archive = builder.makeArchive(
            vehicles: [makeVehicleDTO()],
            chargingSessions: [makeSessionDTO()],
            tariffPresets: [makeTariffDTO()],
            userPreferences: makeUserPreferencesDTO()
        )

        let data = try builder.encode(archive)
        let jsonText = try XCTUnwrap(String(data: data, encoding: .utf8))
        let decoded = try builder.decode(data)

        XCTAssertTrue(jsonText.contains("\n"))
        XCTAssertTrue(jsonText.contains("\"schemaVersion\""))
        XCTAssertEqual(decoded, archive)
    }

    private func makeVehicleDTO(id: UUID = UUID()) -> VehicleBackupDTO {
        VehicleBackupDTO(
            id: id,
            brand: "BMW",
            model: "i4",
            versionName: nil,
            year: 2024,
            enginePowerHP: 340,
            enginePowerKW: 250,
            acMaxChargingKW: 11,
            dcMaxChargingKW: 205,
            batteryCapacityKWh: 80.7,
            factoryConsumptionKWh100km: 18.3,
            colorCode: "#112233",
            silhouetteKey: "bmw_i4_2024",
            isActive: true,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeSessionDTO(id: UUID = UUID()) -> ChargingSessionBackupDTO {
        ChargingSessionBackupDTO(
            id: id,
            vehicleId: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            date: fixedDate,
            stationName: "E5",
            operatorName: "Trugo",
            chargerType: .dc,
            startSoc: 12,
            endSoc: 78,
            energyKWh: 42,
            durationMinutes: 38,
            totalPrice: 510,
            currencyCode: AppCurrencyCode.turkishLira.rawValue,
            odometerKm: 20_500,
            contextTags: [ChargeContextTag.longRoad.rawValue, ChargeContextTag.coldWeather.rawValue],
            note: "Hizli",
            createdAt: fixedDate,
            updatedAt: fixedDate,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeTariffDTO(id: UUID = UUID()) -> TariffPresetBackupDTO {
        TariffPresetBackupDTO(
            id: id,
            title: "AC Gece",
            pricePerKWh: 7.8,
            currencyCode: AppCurrencyCode.turkishLira.rawValue,
            providerName: "Operator",
            createdAt: fixedDate,
            updatedAt: fixedDate,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }

    private func makeUserPreferencesDTO() -> UserPreferencesBackupDTO {
        UserPreferencesBackupDTO(
            id: UserPreferencesBackupDTO.defaultIdentifier,
            selectedCurrencyCode: AppCurrencyCode.turkishLira.rawValue,
            fuelPricePerLiter: 52.4,
            iceConsumptionLPer100Km: 7.1,
            electricityPricePerKWh: 6.9,
            distanceUnit: .km,
            energyUnit: .kilowattHour,
            defaultChargerType: .dc,
            includeOdometerInForms: true,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            schemaVersion: AppSchemaVersion.current.rawValue,
            isDeleted: false
        )
    }
}
#endif
