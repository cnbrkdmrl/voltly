import Foundation

public protocol BackupServiceProtocol {
    func exportBackup(to directoryURL: URL?) throws -> URL
    func exportChargingSessionsCSV(to directoryURL: URL?) throws -> URL
    func importBackup(from fileURL: URL) throws -> BackupImportResult
}
