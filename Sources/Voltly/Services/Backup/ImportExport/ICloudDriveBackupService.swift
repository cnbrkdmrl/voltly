import Foundation

/// Yerel JSON yedeğini iCloud Drive/VoltlyBackups klasörüne kopyalayan servis.
public struct ICloudDriveBackupService: ICloudDriveBackupServiceProtocol {
    private let backupService: BackupServiceProtocol
    private let fileManager: FileManager
    private let containerIdentifier: String?
    private let iCloudDirectoryName: String

    public init(
        backupService: BackupServiceProtocol,
        fileManager: FileManager = .default,
        containerIdentifier: String? = nil,
        iCloudDirectoryName: String = "VoltlyBackups"
    ) {
        self.backupService = backupService
        self.fileManager = fileManager
        self.containerIdentifier = containerIdentifier
        self.iCloudDirectoryName = iCloudDirectoryName
    }

    public func exportBackupToICloudDrive() throws -> URL {
        let localBackupURL = try backupService.exportBackup(to: nil)
        let iCloudDirectory = try resolveICloudDirectory()
        let destinationURL = iCloudDirectory.appendingPathComponent(localBackupURL.lastPathComponent, isDirectory: false)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: localBackupURL, to: destinationURL)
        } catch {
            throw ICloudDriveBackupError.writeFailed(reason: error.localizedDescription)
        }

        return destinationURL
    }

    private func resolveICloudDirectory() throws -> URL {
        guard let ubiquityRoot = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw ICloudDriveBackupError.iCloudUnavailable
        }

        let documentsDirectory = ubiquityRoot.appendingPathComponent("Documents", isDirectory: true)
        let backupDirectory = documentsDirectory.appendingPathComponent(iCloudDirectoryName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            throw ICloudDriveBackupError.inaccessibleContainer
        }

        return backupDirectory
    }
}
