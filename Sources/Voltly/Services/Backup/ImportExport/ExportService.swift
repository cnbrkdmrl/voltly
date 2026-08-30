import Foundation
#if VOLTLY_ENABLE_SWIFTDATA
import SwiftData

public final class ExportService: ExportServiceProtocol {
    private let context: ModelContext
    private let backupBuilder: JSONBackupBuilder
    private let fileExportManager: FileExportManager
    private let dateProvider: () -> Date

    public init(
        context: ModelContext,
        backupBuilder: JSONBackupBuilder = JSONBackupBuilder(),
        fileExportManager: FileExportManager = FileExportManager(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.backupBuilder = backupBuilder
        self.fileExportManager = fileExportManager
        self.dateProvider = dateProvider
    }

    public func exportArchive(to directoryURL: URL? = nil) throws -> URL {
        let vehicles = try context.fetch(FetchDescriptor<VehicleRecord>())
        let sessions = try context.fetch(FetchDescriptor<ChargingSessionRecord>())
        let settings = try appSettingsRecord()

        let archive = backupBuilder.makeArchive(
            vehicles: vehicles.map(backupBuilder.appVehicleDTO(from:)),
            chargingSessions: sessions.map(backupBuilder.appChargingSessionDTO(from:)),
            tariffPresets: [],
            userPreferences: backupBuilder.appUserPreferencesDTO(from: settings)
        )

        let data = try backupBuilder.encode(archive)
        let descriptor = ExportFileDescriptor.backupJSON(at: dateProvider())
        let fileURL = try fileExportManager.makeFileURL(for: descriptor, in: directoryURL)
        try fileExportManager.write(data, to: fileURL)
        return fileURL
    }

    private func appSettingsRecord() throws -> AppSettingsRecord? {
        let settings = try context.fetch(FetchDescriptor<AppSettingsRecord>())
        return settings.first(where: { $0.key == "fuel_baseline" }) ?? settings.first
    }
}
#endif
