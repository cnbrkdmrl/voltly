import Foundation

public final class BackupService: BackupServiceProtocol {
    private let exportService: ExportServiceProtocol
    private let sessionsCSVExportService: SessionsCSVExportServiceProtocol
    private let importService: ImportServiceProtocol

    public init(
        exportService: ExportServiceProtocol,
        sessionsCSVExportService: SessionsCSVExportServiceProtocol,
        importService: ImportServiceProtocol
    ) {
        self.exportService = exportService
        self.sessionsCSVExportService = sessionsCSVExportService
        self.importService = importService
    }

    public func exportBackup(to directoryURL: URL? = nil) throws -> URL {
        try exportService.exportArchive(to: directoryURL)
    }

    public func exportChargingSessionsCSV(to directoryURL: URL? = nil) throws -> URL {
        try sessionsCSVExportService.exportChargingSessionsCSV(to: directoryURL)
    }

    public func importBackup(from fileURL: URL) throws -> BackupImportResult {
        try importService.importArchive(from: fileURL)
    }
}
