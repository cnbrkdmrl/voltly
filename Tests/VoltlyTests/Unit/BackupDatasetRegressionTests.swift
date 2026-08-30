#if canImport(XCTest)
import XCTest
@testable import Voltly

final class BackupDatasetRegressionTests: XCTestCase {
    func testProvidedBackupProducesConsistentMonthlySavingsMetrics() throws {
        let archive = try loadArchiveFixture(named: "voltly-backup-v1-20260324-111240")
        let referenceDate = try XCTUnwrap(Self.fixtureDate("2026-03-31T12:00:00Z"))
        let vehicle = try XCTUnwrap(makeActiveVehicle(from: archive))
        let sessions = makeSessions(from: archive, vehicleID: vehicle.id)
        let preferences = makeFuelBaseline(from: archive.userPreferences)

        let report = SavingsCalculationEngine().calculate(
            vehicle: vehicle,
            sessions: sessions,
            preferences: preferences,
            referenceDate: referenceDate
        )

        let month = try XCTUnwrap(report.thisMonth)

        XCTAssertEqual(month.totalEvCost, 8_320.72, accuracy: 0.01)
        XCTAssertEqual(month.totalEnergyKWh, 771.425, accuracy: 0.001)

        XCTAssertEqual(month.avgConsumptionKWh100km, 28.59, accuracy: 0.2)
        XCTAssertEqual(month.evCostPer100Km ?? -1, 308.36, accuracy: 1.0)
        XCTAssertEqual(month.gasolineCostPer100Km ?? -1, 422.5, accuracy: 0.01)
        XCTAssertEqual(month.gasolineEquivalentCost, 11_395.74, accuracy: 20.0)
        XCTAssertEqual(month.savingsAmount, 3_075.02, accuracy: 20.0)
        XCTAssertEqual(month.savingsPercent ?? -1, 26.98, accuracy: 1.0)

        XCTAssertEqual(month.calculationMode.consumption, .realData)
        XCTAssertEqual(month.calculationMode.distance, .odometer)
        XCTAssertFalse(month.explanationText.contains("daha pahali"))

        XCTAssertGreaterThan(report.carbonSummary.avoidedCO2Kg, 300)
        XCTAssertGreaterThan(report.carbonSummary.monthlyAvoidedCO2Kg, 300)
        XCTAssertGreaterThanOrEqual(report.carbonSummary.equivalentTrees, 7)
    }

    private func loadArchiveFixture(named name: String) throws -> BackupArchiveDTO {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("\(name).json")

        let data = try Data(contentsOf: fixtureURL)
        return try JSONBackupBuilder().decode(data)
    }

    private func makeActiveVehicle(from archive: BackupArchiveDTO) -> Vehicle? {
        let candidate = archive.vehicles.first(where: { $0.isDeleted == false && ($0.isActive ?? false) })
            ?? archive.vehicles.first(where: { !$0.isDeleted })

        guard let dto = candidate else {
            return nil
        }

        return Vehicle(
            id: dto.id,
            brand: dto.brand,
            model: dto.model,
            year: dto.year ?? 2026,
            enginePowerHP: dto.enginePowerHP,
            enginePowerKW: dto.enginePowerKW,
            acMaxChargingKW: dto.acMaxChargingKW,
            dcMaxChargingKW: dto.dcMaxChargingKW,
            batteryCapacityKWh: dto.batteryCapacityKWh ?? 0,
            factoryConsumptionKWh100km: dto.factoryConsumptionKWh100km,
            colorCode: dto.colorCode,
            silhouetteKey: dto.silhouetteKey,
            isActive: dto.isActive ?? true,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    private func makeSessions(from archive: BackupArchiveDTO, vehicleID: UUID) -> [ChargingSession] {
        archive.chargingSessions
            .filter { !$0.isDeleted && $0.vehicleId == vehicleID }
            .map { dto in
                ChargingSession(
                    id: dto.id,
                    vehicleID: dto.vehicleId,
                    sessionDate: dto.date,
                    chargeMethod: dto.chargerType == .dc ? .publicDC : .publicAC,
                    stationBrand: dto.operatorName,
                    locationName: dto.stationName,
                    priceTotal: dto.totalPrice ?? 0,
                    currencyCode: dto.currencyCode,
                    energyKWh: dto.energyKWh,
                    energyIsEstimated: false,
                    socStart: dto.startSoc ?? 0,
                    socEnd: dto.endSoc ?? (dto.startSoc ?? 0),
                    isFullCharge: (dto.endSoc ?? 0) >= 99.5,
                    durationMin: dto.durationMinutes,
                    odometerKM: dto.odometerKm,
                    contextTags: [],
                    notes: dto.note,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt
                )
            }
    }

    private func makeFuelBaseline(from dto: UserPreferencesBackupDTO) -> FuelBaselineSettings {
        FuelBaselineSettings(
            fuelPricePerLiter: dto.fuelPricePerLiter ?? AppConstants.defaultFuelPricePerLiter,
            iceConsumptionLPer100Km: dto.iceConsumptionLPer100Km ?? AppConstants.defaultICEConsumptionLPer100Km,
            currencyCode: dto.selectedCurrencyCode,
            electricityPricePerKWh: dto.electricityPricePerKWh ?? AppConstants.defaultElectricityPricePerKWh
        )
    }

    private static func fixtureDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
}
#endif
