import Foundation

public protocol ImportServiceProtocol {
    func importArchive(from fileURL: URL) throws -> BackupImportResult
}
