#if canImport(XCTest)
import XCTest
@testable import Voltly

#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

@MainActor
final class BackupImportFlowViewModelTests: XCTestCase {
    func testImportedBackupPopulatesDashboardInsightsAndSavings() throws {
        let container = try SwiftDataFactory.makeModelContainer(inMemory: true)
        let context = ModelContext(container)

        let vehicleRepository = SwiftDataVehicleRepository(context: context)
        let sessionRepository = SwiftDataChargingSessionRepository(context: context)
        let settingsRepository = SwiftDataSettingsRepository(context: context)
        let environment = AppEnvironment(
            analytics: NoopAnalyticsTracker(),
            crashReporter: NoopCrashReporter(),
            vehicleCatalog: StaticReferenceVehicleCatalog(),
            unplugReminderScheduler: NoopUnplugReminderScheduler(),
            vehicleRepository: vehicleRepository,
            chargingSessionRepository: sessionRepository,
            settingsRepository: settingsRepository,
            goalRepository: InMemoryGoalRepository(),
            chargingOperatorRepository: InMemoryChargingOperatorRepository()
        )

        let staleVehicle = Vehicle(
            brand: "Tesla",
            model: "Model Y",
            year: 2024,
            batteryCapacityKWh: 75,
            factoryConsumptionKWh100km: 16,
            isActive: true
        )
        try vehicleRepository.upsert(vehicle: staleVehicle)

        let backupService = BackupService(
            exportService: ExportService(
                vehicleRepository: vehicleRepository,
                chargingSessionRepository: sessionRepository,
                settingsRepository: settingsRepository
            ),
            sessionsCSVExportService: SessionsCSVExportService(
                listSessionsUseCase: environment.listChargingSessionsUseCase,
                vehicleRepository: vehicleRepository
            ),
            importService: ImportService(context: context)
        )
        let backupViewModel = BackupSettingsViewModel(
            environment: environment,
            backupService: backupService
        )

        let importedVehicleID = UUID()
        let archiveURL = try makeArchiveFile(
            vehicleID: importedVehicleID,
            exportedAt: .now,
            sessionDate: .now
        )
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        backupViewModel.importBackup(from: archiveURL)

        let dashboardViewModel = DashboardViewModel(environment: environment)
        dashboardViewModel.load()

        let insightsViewModel = InsightsViewModel(environment: environment)
        insightsViewModel.load()

        let savingsViewModel = SavingsViewModel(environment: environment)
        savingsViewModel.load()

        XCTAssertEqual(backupViewModel.lastImportResult?.failedCount, 0)
        XCTAssertEqual(try vehicleRepository.fetchActiveVehicle()?.id, importedVehicleID)

        XCTAssertTrue(dashboardViewModel.hasActiveVehicle)
        XCTAssertEqual(dashboardViewModel.totalSessionCount, 1)
        XCTAssertEqual(dashboardViewModel.snapshot.monthlySessionCount, 1)
        XCTAssertGreaterThan(dashboardViewModel.snapshot.monthlyTotalEnergy, 0)

        XCTAssertTrue(insightsViewModel.hasActiveVehicle)
        XCTAssertEqual(insightsViewModel.totalSessionCount, 1)
        XCTAssertEqual(insightsViewModel.monthlySessionCount, 1)
        XCTAssertFalse(insightsViewModel.monthlyEVCostTrend.isEmpty)

        XCTAssertTrue(savingsViewModel.hasActiveVehicle)
        XCTAssertEqual(savingsViewModel.totalSessionCount, 1)
        XCTAssertEqual(savingsViewModel.monthlySessionCount, 1)
        XCTAssertGreaterThan(savingsViewModel.monthlyEnergyKWh, 0)
    }

    private func makeArchiveFile(
        vehicleID: UUID,
        exportedAt: Date,
        sessionDate: Date
    ) throws -> URL {
        let archive = BackupArchiveDTO(
            schemaVersion: AppSchemaVersion.current.rawValue,
            exportedAt: exportedAt,
            appVersion: "1.0",
            vehicles: [
                VehicleBackupDTO(
                    id: vehicleID,
                    brand: "BYD",
                    model: "Seal",
                    versionName: nil,
                    batteryCapacityKWh: 82.5,
                    createdAt: exportedAt.addingTimeInterval(-3_600),
                    updatedAt: exportedAt,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ],
            chargingSessions: [
                ChargingSessionBackupDTO(
                    id: UUID(),
                    vehicleId: vehicleID,
                    date: sessionDate,
                    stationName: "Kadikoy",
                    operatorName: "ZES",
                    chargerType: .publicDC,
                    startSoc: 22,
                    endSoc: 78,
                    energyKWh: 35,
                    durationMinutes: 42,
                    totalPrice: 480,
                    currencyCode: "TRY",
                    odometerKm: 14_250,
                    note: "Import smoke test",
                    createdAt: exportedAt.addingTimeInterval(-1_800),
                    updatedAt: exportedAt,
                    schemaVersion: AppSchemaVersion.current.rawValue,
                    isDeleted: false
                )
            ],
            tariffPresets: [],
            userPreferences: .default()
        )

        let data = try JSONBackupBuilder().encode(archive)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voltly-import-flow-\(UUID().uuidString).json")
        try data.write(to: url)
        return url
    }
}
#else
final class BackupImportFlowViewModelTests: XCTestCase {
    func testBackupImportFlowSkippedOutsideiOSBuild() {
        XCTAssertTrue(true)
    }
}
#endif
#endif
