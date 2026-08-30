import Foundation

public struct BackupImportResult: Equatable, Sendable {
    public var insertedCount: Int
    public var updatedCount: Int
    public var skippedCount: Int
    public var failedCount: Int
    public var warnings: [String]

    public init(
        insertedCount: Int = 0,
        updatedCount: Int = 0,
        skippedCount: Int = 0,
        failedCount: Int = 0,
        warnings: [String] = []
    ) {
        self.insertedCount = insertedCount
        self.updatedCount = updatedCount
        self.skippedCount = skippedCount
        self.failedCount = failedCount
        self.warnings = warnings
    }

    public var totalProcessedCount: Int {
        insertedCount + updatedCount + skippedCount + failedCount
    }

    public mutating func append(_ decision: BackupMergeDecision) {
        switch decision {
        case .inserted:
            insertedCount += 1
        case .updated:
            updatedCount += 1
        case .skipped:
            skippedCount += 1
        case .failed(let reason):
            failedCount += 1
            warnings.append(reason)
        }
    }

    public mutating func appendWarning(_ warning: String) {
        warnings.append(warning)
    }
}
