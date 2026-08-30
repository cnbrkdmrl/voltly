import Foundation

public struct BackupSettingsState: Equatable, Sendable {
    public var lastExportDate: Date?
    public var lastImportDate: Date?
    public var canExport: Bool
    public var canImport: Bool

    public init(
        lastExportDate: Date? = nil,
        lastImportDate: Date? = nil,
        canExport: Bool = true,
        canImport: Bool = true
    ) {
        self.lastExportDate = lastExportDate
        self.lastImportDate = lastImportDate
        self.canExport = canExport
        self.canImport = canImport
    }
}
